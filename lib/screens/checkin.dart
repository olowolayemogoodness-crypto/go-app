import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api.dart';
import '../theme/prefs.dart';
import '../widgets/common.dart';
import 'capture.dart';
import 'verdict.dart';

/// One activity's check-in: camera (code word) or GitHub, plus partner fallback and appeal.
class CheckInScreen extends StatefulWidget {
  final String pledgeId, actId, title, kind, partnerName;
  final int day;
  const CheckInScreen({
    super.key,
    required this.pledgeId,
    required this.actId,
    required this.title,
    required this.kind,
    required this.day,
    required this.partnerName,
  });
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  String? _code;
  int? _expiresMs;
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(String token) async {
    final link = partnerLink(token);
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showSnack(context, 'Partner link copied.');
    await Share.share('Please confirm my GO check-in: $link');
  }

  Future<void> _getCode() => _run(() async {
        final r = await Api.issueCode(widget.pledgeId, widget.actId);
        if (r['codeWord'] != null) {
          setState(() {
            _code = r['codeWord'] as String;
            _expiresMs = (r['expiresAtMs'] as num).toInt();
          });
        }
      });

  Future<void> _github() => _run(() async {
        final r = await Api.githubVerify(widget.pledgeId, widget.actId);
        if (!mounted) return;
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => VerdictScreen(
                    pledgeId: widget.pledgeId, actId: widget.actId, result: r, githubMode: true)));
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .doc('pledges/${widget.pledgeId}/acts/${widget.day}_${widget.actId}')
          .snapshots(),
      builder: (context, snap) {
        final ck = snap.data?.data() ?? {};
        final status = (ck['status'] as String?) ?? 'pending';
        return PageShell(
          title: 'Check in',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(widget.title, style: t.headlineSmall)),
              const SizedBox(height: 16),
              _body(context, status, ck),
            ],
          ),
        );
      },
    );
  }

  Widget _info(BuildContext context, String text, IconData icon) {
    return ChunkyCard(
      child: Row(children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ]),
    );
  }

  Widget _body(BuildContext context, String status, Map<String, dynamic> ck) {
    switch (status) {
      case 'passed':
      case 'passed_by_partner':
        return _info(context, 'Done. Your battery is charged for this one.', Icons.check_circle);
      case 'pending_partner':
      case 'appealed':
        final tok = ck['partnerToken'] as String?;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _info(context, 'Waiting for ${widget.partnerName} to review. Nothing is lost until they answer.',
              Icons.hourglass_empty),
          if ((ck['reason'] as String?)?.isNotEmpty == true)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('Checker note: ${ck['reason']}')),
          if (tok != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: BigButton(
                  label: 'Share link with partner', icon: Icons.share, outlined: true, onPressed: () => _share(tok)),
            ),
        ]);
      case 'failed':
        final attempts = (ck['attempts'] as num?)?.toInt() ?? 0;
        final appealed = ck['appealed'] == true;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _info(context, 'Not confirmed. ${ck['reason'] ?? ''}', Icons.info_outline),
          const SizedBox(height: 12),
          if (!appealed)
            BigButton(
              label: 'Appeal once to my partner',
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final r = await Api.appeal(widget.pledgeId, widget.actId, widget.day);
                        await _share(r['partnerToken'] as String);
                      }),
            ),
          if (attempts < 2 && widget.kind == 'camera') ...[
            const SizedBox(height: 8),
            BigButton(label: 'Try again with a new code', outlined: true, onPressed: _busy ? null : _getCode),
            ..._codeCard(context),
          ],
        ]);
      default:
        return _pending(context);
    }
  }

  List<Widget> _codeCard(BuildContext context) {
    final p = Pal.of(context);
    final t = Theme.of(context).textTheme;
    final expired = _expiresMs != null && DateTime.now().millisecondsSinceEpoch > _expiresMs!;
    if (_code == null || expired) return const [];
    return [
      const SizedBox(height: 16),
      ChunkyCard(
        color: p.sunSoft,
        child: Column(children: [
          Text('Say or show this code word', style: t.titleMedium?.copyWith(color: p.onSun)),
          const SizedBox(height: 8),
          Semantics(
              label: 'Code word: $_code',
              child: Text(_code!, style: t.displaySmall?.copyWith(color: p.onSun))),
          const SizedBox(height: 8),
          Text('Write it on paper or show it on another screen. It works once and lasts 30 minutes.',
              textAlign: TextAlign.center, style: TextStyle(color: p.onSun)),
        ]),
      ),
      const SizedBox(height: 16),
      BigButton(
        label: 'Open camera',
        icon: Icons.photo_camera,
        onPressed: _busy
            ? null
            : () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CaptureScreen(
                            pledgeId: widget.pledgeId, actId: widget.actId, codeWord: _code!)));
                if (mounted) setState(() => _code = null);
              },
      ),
    ];
  }

  Widget _pending(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (widget.kind == 'github') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BigButton(
            label: _busy ? 'Checking...' : 'Check GitHub',
            icon: Icons.code,
            onPressed: _busy ? null : _github),
        const SizedBox(height: 8),
        BigButton(
          label: 'Ask my partner instead',
          outlined: true,
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final r = await Api.askPartner(widget.pledgeId, widget.actId);
                    await _share(r['partnerToken'] as String);
                  }),
        ),
      ]);
    }
    final hasCode = _code != null &&
        !(_expiresMs != null && DateTime.now().millisecondsSinceEpoch > _expiresMs!);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!hasCode) ...[
        BigButton(
            label: _busy ? 'Getting code...' : 'Get my code word',
            icon: Icons.key,
            onPressed: _busy ? null : _getCode),
        const SizedBox(height: 8),
        Text('Camera only. You will show your activity and the code word.',
            style: t.bodyMedium, textAlign: TextAlign.center),
      ],
      ..._codeCard(context),
    ]);
  }
}
