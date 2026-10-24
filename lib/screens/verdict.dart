import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api.dart';
import '../widgets/common.dart';

/// Shows PASS / UNSURE / FAIL with the reason. Calm colours, shame-free wording.
class VerdictScreen extends StatefulWidget {
  final String pledgeId;
  final String actId;
  final Map<String, dynamic> result;
  final bool githubMode;
  const VerdictScreen(
      {super.key, required this.pledgeId, required this.actId, required this.result, this.githubMode = false});
  @override
  State<VerdictScreen> createState() => _VerdictScreenState();
}

class _VerdictScreenState extends State<VerdictScreen> {
  bool _busy = false;
  String? _partnerToken;

  @override
  void initState() {
    super.initState();
    _partnerToken = widget.result['partnerToken'] as String?;
  }

  Future<void> _share(String token) async {
    final link = partnerLink(token);
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showSnack(context, 'Partner link copied.');
    await Share.share('Please confirm my GO check-in: $link');
  }

  Future<void> _askPartner() async {
    setState(() => _busy = true);
    try {
      final r = await Api.askPartner(widget.pledgeId, widget.actId);
      final tok = r['partnerToken'] as String;
      setState(() => _partnerToken = tok);
      await _share(tok);
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final verdict = (r['verdict'] as String?) ?? 'UNSURE';
    final reason = (r['reason'] as String?) ?? '';
    final evidence = (r['evidence'] as List?) ?? const [];
    final needsPartner = r['needsPartner'] == true;
    final canAskPartner = r['canAskPartner'] == true;
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    late String title;
    late String body;
    late IconData icon;
    switch (verdict) {
      case 'PASS':
        title = 'Verified';
        body = 'Battery charged. Nice work.';
        icon = Icons.check_circle;
        break;
      case 'FAIL':
        title = 'Not confirmed';
        body = 'The checker did not see the goal. Your partner will take a look, and you can appeal once.  Nothing is lost yet.';
        icon = Icons.help_outline;
        break;
      default:
        title = 'Not sure yet';
        body = 'The checker could not be certain. That is not a failure. Your partner can confirm it.';
        icon = Icons.help_outline;
    }

    return PageShell(
      title: 'Result',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: verdict == 'PASS' ? s.primaryContainer : s.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(icon, size: 48, semanticLabel: title),
                  const SizedBox(height: 8),
                  Semantics(header: true, child: Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
                  const SizedBox(height: 8),
                  Text(body, textAlign: TextAlign.center),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Why: $reason', textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Evidence', style: t.titleMedium),
            for (final e in evidence)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${(e as Map)['text']}'),
                subtitle: SelectableText('${e['url']}'),
              ),
          ],
          const SizedBox(height: 16),
          if (needsPartner && _partnerToken != null)
            FilledButton.icon(
              onPressed: () => _share(_partnerToken!),
              icon: const Icon(Icons.share),
              label: const Text('Send link to my partner'),
            ),
          if (canAskPartner && _partnerToken == null)
            FilledButton(
              onPressed: _busy ? null : _askPartner,
              child: const Text('Ask my partner to confirm'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }
}
