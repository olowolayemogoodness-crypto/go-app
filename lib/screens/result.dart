import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/prefs.dart';
import '../widgets/common.dart';
import 'new_pledge.dart';

class ResultScreen extends StatelessWidget {
  final String pledgeId;
  const ResultScreen({super.key, required this.pledgeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.doc('pledges/$pledgeId').snapshots(),
      builder: (context, snap) {
        final p = snap.data?.data();
        if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final won = p['status'] == 'won';
        final t = Theme.of(context).textTheme;
        final pal = Pal.of(context);
        final premium = p['premium'];
        final refund = p['refundAmount'];
        final fs = (p['finalStats'] as Map?) ?? const {};
        final msg = won
            ? 'You did something every day and finished ${fs['overallPct'] ?? 90}% or more. '
                'You get $refund of your $premium premium back (simulated).'
            : 'The program ended because the daily streak broke or too many activities were missed. '
                'The simulated premium of $premium is not returned. Nothing real was charged.';
        return PageShell(
          title: won ? 'You won' : 'Program ended',
          showBack: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChunkyCard(
                color: won ? pal.sunSoft : pal.card,
                angle: won ? -0.01 : 0,
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Icon(won ? Icons.emoji_events : Icons.flag_outlined, size: 56, color: won ? pal.onSun : pal.ink),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(won ? '+$refund back!' : 'Not this time.',
                        style: t.headlineMedium?.copyWith(color: won ? pal.onSun : pal.ink)),
                  ),
                  const SizedBox(height: 12),
                  Text(msg, textAlign: TextAlign.center, style: TextStyle(color: won ? pal.onSun : pal.ink)),
                  const SizedBox(height: 12),
                  Text('SIMULATED - no real money was held or moved.',
                      style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: won ? pal.onSun : pal.ink),
                      textAlign: TextAlign.center),
                ]),
              ),
              const SizedBox(height: 16),
              BigButton(
                label: 'Share',
                icon: Icons.share,
                outlined: true,
                onPressed: () => Share.share(won
                    ? 'I finished a 30-day streak on GO and won my simulated refund.'
                    : 'I tried a 30-day challenge on GO. Round two soon.'),
              ),
              const SizedBox(height: 12),
              BigButton(
                label: 'Start a new 30 days',
                icon: Icons.bolt,
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const NewPledgeScreen())),
              ),
            ],
          ),
        );
      },
    );
  }
}
