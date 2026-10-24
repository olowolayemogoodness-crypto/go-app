import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/prefs.dart';
import '../widgets/common.dart';
import 'new_pledge.dart';
import 'result.dart';
import 'today.dart';

/// Chooses the one screen to show: Home (active program), Result (finished), or Welcome.
class HomeGate extends StatelessWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pledges')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const PageShell(
              title: 'GO',
              showBack: false,
              child: Text('Could not load your program. Check your connection and reload.'));
        }
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final ta = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 1 << 50;
            final tb = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 1 << 50;
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) return const WelcomeScreen();
        final latest = docs.first;
        final status = latest.data()['status'];
        if (status == 'won' || status == 'lost') return ResultScreen(pledgeId: latest.id);
        return TodayScreen(pledgeId: latest.id);
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Pal.of(context);
    return PageShell(
      title: 'GO',
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text('30 days.\nCharge the battery.\nGet half back.',
                style: t.headlineLarge?.copyWith(color: p.primary)),
          ),
          const SizedBox(height: 16),
          Text(
            'Pay a simulated premium and pick up to 5 daily activities. Every one you finish charges your battery. '
            'Do something every day for 30 days and finish at least 90% of everything, and you get half your premium back. '
            'Miss the mark and the app keeps it. An AI checks your proof, but it never fails you alone: your partner can always overrule it.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 28),
          BigButton(
            label: 'Start my 30 days',
            icon: Icons.bolt,
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const NewPledgeScreen())),
          ),
          const SizedBox(height: 24),
          Text('Make it easier to read', style: t.titleMedium),
          const AccessibilityToggles(),
        ],
      ),
    );
  }
}
