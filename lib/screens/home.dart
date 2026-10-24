import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'new_pledge.dart';
import 'result.dart';
import 'shell.dart';

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
        if (docs.isEmpty) return const NewPledgeScreen();
        final latest = docs.first;
        final status = latest.data()['status'];
        if (status == 'won' || status == 'lost') return ResultScreen(pledgeId: latest.id);
        return AppShell(pledgeId: latest.id);
      },
    );
  }
}
