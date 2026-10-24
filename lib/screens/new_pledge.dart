import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/api.dart';
import '../widgets/common.dart';
import '../theme/prefs.dart';

/// "Start your 30 days": pick activities, pay a simulated premium, name a partner.
class NewPledgeScreen extends StatefulWidget {
  const NewPledgeScreen({super.key});
  @override
  State<NewPledgeScreen> createState() => _NewPledgeScreenState();
}

class _Act {
  final TextEditingController title = TextEditingController();
  String kind = 'camera';
}

class _NewPledgeScreenState extends State<NewPledgeScreen> {
  final List<_Act> _acts = [_Act()];
  double _premium = 1000;
  final _partner = TextEditingController();
  final _github = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// Starter activities suggested by the questionnaire answers.
  Future<void> _prefill() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final s = await FirebaseFirestore.instance.doc('users/$uid').get();
      final sug = ((s.data()?['profile'] as Map?)?['suggested'] as List?)?.cast<Map>();
      if (sug == null || sug.isEmpty || !mounted) return;
      if (_acts.length == 1 && _acts[0].title.text.isEmpty) {
        setState(() {
          _acts.clear();
          for (final m in sug) {
            final a = _Act();
            a.title.text = '${m['title']}';
            a.kind = '${m['kind']}' == 'github' ? 'github' : 'camera';
            _acts.add(a);
          }
        });
      }
    } catch (_) {}
  }

  bool get _hasGithub => _acts.any((a) => a.kind == 'github');

  @override
  void dispose() {
    for (final a in _acts) {
      a.title.dispose();
    }
    _partner.dispose();
    _github.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final acts = [
      for (final a in _acts)
        if (a.title.text.trim().isNotEmpty) {'title': a.title.text.trim(), 'kind': a.kind}
    ];
    if (acts.isEmpty) return showSnack(context, 'Add at least one activity.');
    if (_partner.text.trim().isEmpty) return showSnack(context, 'Name your accountability partner.');
    if (_hasGithub && _github.text.trim().isEmpty) {
      return showSnack(context, 'Enter your GitHub username.');
    }
    setState(() => _busy = true);
    try {
      await Api.createPledge({
        'activities': acts,
        'premium': _premium.round(),
        'partnerName': _partner.text.trim(),
        'githubUser': _hasGithub ? _github.text.trim() : '',
        'tzOffsetMin': DateTime.now().timeZoneOffset.inMinutes,
      });
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final t = Theme.of(context).textTheme;
    final premium = _premium.round();
    return PageShell(
      title: 'Start your 30 days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('1. What will you do every day?', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('Up to 5 activities. Each one you finish charges your battery.',
              style: TextStyle(color: p.muted)),
          const SizedBox(height: 12),
          for (var i = 0; i < _acts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChunkyCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _acts[i].title,
                          maxLength: 80,
                          decoration: InputDecoration(labelText: 'Activity ${i + 1}', counterText: ''),
                        ),
                      ),
                      if (_acts.length > 1)
                        IconButton(
                          tooltip: 'Remove activity ${i + 1}',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _acts.removeAt(i)),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'camera', label: Text('Camera proof'), icon: Icon(Icons.photo_camera)),
                        ButtonSegment(value: 'github', label: Text('GitHub'), icon: Icon(Icons.code)),
                      ],
                      selected: {_acts[i].kind},
                      onSelectionChanged: (s) => setState(() => _acts[i].kind = s.first),
                    ),
                  ],
                ),
              ),
            ),
          if (_acts.length < 5)
            OutlinedButton.icon(
              onPressed: () => setState(() => _acts.add(_Act())),
              icon: const Icon(Icons.add),
              label: const Text('Add another activity'),
            ),
          if (_hasGithub) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _github,
              decoration: const InputDecoration(labelText: 'Your GitHub username'),
            ),
          ],
          const SizedBox(height: 28),
          Text('2. Pay your premium', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('Simulated coins only. No real money.', style: TextStyle(color: p.muted)),
          Slider(
            value: _premium,
            min: 100,
            max: 3000,
            divisions: 29,
            label: '$premium',
            semanticFormatterCallback: (v) => '${v.round()} simulated coins',
            onChanged: (v) => setState(() => _premium = v),
          ),
          ChunkyCard(
            color: p.ink,
            padding: const EdgeInsets.all(14),
            child: Text(
              'Premium: $premium. Finish all 30 days with at least 90% done and you get '
              '${premium ~/ 2} back. Otherwise GO keeps the premium.',
              style: TextStyle(color: p.sunSoft, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
          const SizedBox(height: 28),
          Text('3. Pick a partner', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('Someone who can overrule the checker. They answer with one link, no account.',
              style: TextStyle(color: p.muted)),
          const SizedBox(height: 8),
          TextField(controller: _partner, decoration: const InputDecoration(labelText: 'Partner name')),
          const SizedBox(height: 16),
          Text(
            'Win rule: do at least one activity every single day (3 grace passes protect you) '
            'and finish at least 90% of all activities.',
            style: TextStyle(color: p.muted),
          ),
          const SizedBox(height: 16),
          BigButton(label: _busy ? 'Starting...' : 'Pay $premium and start', icon: Icons.bolt, onPressed: _busy ? null : _start),
        ],
      ),
    );
  }
}
