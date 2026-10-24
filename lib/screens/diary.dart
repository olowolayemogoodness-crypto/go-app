import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api.dart';
import '../theme/prefs.dart';
import '../widgets/common.dart';

/// Personal diary: save video links, then find them by describing them.
/// The agent reads only titles, authors and your notes. It cannot watch videos.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final _q = TextEditingController();
  bool _busy = false;
  List<Map<String, dynamic>>? _matches;
  int _total = 0;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (_q.text.trim().length < 3) return showSnack(context, 'Describe what you are looking for.');
    setState(() => _busy = true);
    try {
      final r = await Api.findLinks(_q.text.trim());
      if (!mounted) return;
      setState(() {
        _matches = [for (final m in (r['matches'] as List)) Map<String, dynamic>.from(m as Map)];
        _total = (r['total'] as num).toInt();
      });
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showSnack(context, 'Could not open the link.');
  }

  Future<void> _delete(String id) async {
    try {
      await Api.deleteLink(id);
      if (mounted) setState(() => _matches?.removeWhere((m) => m['id'] == id));
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  Future<void> _save() async {
    final url = TextEditingController();
    final title = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Save a link'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Link (https://...)')),
            const SizedBox(height: 10),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title (needed for sites other than YouTube, TikTok, Vimeo)')),
            const SizedBox(height: 10),
            TextField(controller: note, maxLength: 200, decoration: const InputDecoration(labelText: 'Your note (helps you find it)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await Api.saveLink(url.text.trim(), title.text.trim(), note.text.trim());
      if (mounted) showSnack(context, 'Saved: ${r['title']}');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  String _ago(num ms) {
    final d = DateTime.now().millisecondsSinceEpoch - ms.toInt();
    final days = (d / 86400000).floor();
    if (days < 1) return 'Saved today';
    if (days < 14) return 'Saved $days day${days == 1 ? '' : 's'} ago';
    return 'Saved ${(days / 7).round()} weeks ago';
  }

  Widget _card(Map<String, dynamic> m, bool first) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ChunkyCard(
        shadow: first,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                  color: p.sunSoft, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.ink, width: 1.5)),
              child: Text('${m['site']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.onSun)),
            ),
            const SizedBox(width: 8),
            if (m['savedAtMs'] != null) Text(_ago(m['savedAtMs'] as num), style: TextStyle(fontSize: 12, color: p.muted)),
          ]),
          const SizedBox(height: 8),
          Text('${m['title']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if ('${m['note'] ?? ''}'.isNotEmpty)
            Text('Your note: ${m['note']}', style: TextStyle(fontSize: 14, color: p.muted)),
          if ('${m['why'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: p.lilac, borderRadius: BorderRadius.circular(12)),
              child: Text.rich(TextSpan(children: [
                const TextSpan(text: 'Why it matched: ', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: '${m['why']}'),
              ]), style: TextStyle(fontSize: 13, color: p.lilacInk)),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            OutlinedButton(onPressed: () => _open('${m['url']}'), child: const Text('Open link')),
            const SizedBox(width: 8),
            TextButton(onPressed: () => _delete('${m['id']}'), child: const Text('Remove')),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final t = Theme.of(context).textTheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return PageShell(
      title: 'Saves',
      showBadge: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Save videos you want to remember. Later, describe what you remember and your assistant finds it. '
              'It matches titles, authors and your notes. It cannot watch the video itself.',
              style: TextStyle(color: p.muted, height: 1.5)),
          const SizedBox(height: 16),
          TextField(
            controller: _q,
            minLines: 3,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'What are you looking for?'),
          ),
          const SizedBox(height: 8),
          BigButton(label: _busy ? 'Looking...' : 'Find it', icon: Icons.search, onPressed: _busy ? null : _find),
          const SizedBox(height: 16),
          if (_matches != null) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${_matches!.length} match${_matches!.length == 1 ? '' : 'es'}', style: t.titleLarge),
              Text('from $_total saved links', style: TextStyle(fontSize: 13, color: p.muted)),
            ]),
            const SizedBox(height: 12),
            if (_matches!.isEmpty) const Text('Nothing matched. Try different words, or save the link with a clearer note.'),
            for (var i = 0; i < _matches!.length; i++) _card(_matches![i], i == 0),
          ] else if (uid != null)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users/$uid/diary')
                  .orderBy('savedAtMs', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, s) {
                final docs = s.data?.docs ?? const [];
                if (docs.isEmpty) return const Text('No links saved yet.');
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Recently saved', style: t.titleLarge),
                  const SizedBox(height: 12),
                  for (final d in docs) _card({...d.data(), 'id': d.id}, false),
                ]);
              },
            ),
          const SizedBox(height: 8),
          BigButton(label: 'Save a new link', icon: Icons.add, outlined: true, onPressed: _save),
        ],
      ),
    );
  }
}
