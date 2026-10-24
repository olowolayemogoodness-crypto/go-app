import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth.dart';
import '../theme/prefs.dart';
import '../widgets/common.dart';
import '../widgets/github_widget.dart';

/// Profile tab. The activity rings and habit editing come in a later step.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final p = Pal.of(context);
    final name = (u?.displayName?.isNotEmpty ?? false)
        ? u!.displayName!
        : (u?.email?.isNotEmpty ?? false)
            ? u!.email!
            : 'Guest';
    return PageShell(
      title: 'Profile',
      showBack: false,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: u == null ? null : FirebaseFirestore.instance.doc('users/${u.uid}').snapshots(),
        builder: (context, snap) {
          final xp = (snap.data?.data()?['xp'] as num?)?.toInt() ?? 0;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ChunkyCard(
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: p.sunSoft,
                  backgroundImage: u?.photoURL != null ? NetworkImage(u!.photoURL!) : null,
                  child: u?.photoURL == null ? Icon(Icons.person_rounded, color: p.orange, size: 30) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    XpChip(xp: xp),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            ChunkyCard(
              child: Text('Your activity rings and habit editing are coming next.',
                  style: TextStyle(color: p.muted, height: 1.4)),
            ),
            const SizedBox(height: 24),
            const BigButton(label: 'Sign out', icon: Icons.logout_rounded, outlined: true, onPressed: AuthService.signOut),
          ]);
        },
      ),
    );
  }
}
