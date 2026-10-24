import 'package:flutter/material.dart';

import '../services/api.dart';
import '../widgets/common.dart';

/// Public no-login page reached at /confirm/{token}. One-time use.
class PartnerScreen extends StatefulWidget {
  final String token;
  const PartnerScreen({super.key, required this.token});
  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  Map<String, dynamic>? _info;
  String? _error;
  bool _busy = false;
  bool _done = false;
  bool? _answer;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    Api.partnerGet(widget.token).then((v) {
      if (mounted) setState(() => _info = v);
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  Future<void> _send(bool yes) async {
    setState(() => _busy = true);
    try {
      await Api.partnerConfirm(widget.token, yes, _note.text.trim());
      setState(() {
        _done = true;
        _answer = yes;
      });
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget body;
    if (_error != null) {
      body = Text(_error!);
    } else if (_info == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_done) {
      body = Text(
          _answer == true
              ? 'Thank you. You confirmed the check-in.'
              : 'Thank you. You said it was not done. This link can no longer be used.',
          style: t.titleMedium);
    } else {
      final i = _info!;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
              header: true,
              child: Text('Hi ${i['partnerName']}, did they do it?',
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(height: 12),
          Text('Goal: ${i['goal']}', style: t.titleMedium),
          Text('Day ${i['day']} of ${i['days']}'),
          if ((i['aiReason'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Automatic checker note: ${i['aiReason']}'),
          ],
          if (i['kind'] == 'appeal')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('This is an appeal. Please look again.'),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLength: 200,
            decoration: const InputDecoration(
                labelText: 'Optional note', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: _busy ? null : () => _send(true), child: const Text('Yes, they did it')),
          const SizedBox(height: 8),
          OutlinedButton(
              onPressed: _busy ? null : () => _send(false), child: const Text('No, not done')),
          const SizedBox(height: 8),
          const Text('You can answer once. This link stops working after that.'),
        ],
      );
    }
    return PageShell(title: 'Partner check', showBack: false, child: body);
  }
}
