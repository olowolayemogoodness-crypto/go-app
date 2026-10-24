import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _ink = Color(0xFF1B1B1F);
const _muted = Color(0xFF6C6C75);
const _orange = Color(0xFFE08813);
const _soft = Color(0xFFFFF0DA);
const _line = Color(0xFFE9DFD2);

/// Publishes your own score so you can appear on the leaderboard (opt-in, signed-in users only).
class Leaderboard {
  static String displayName(User u) {
    final n = u.displayName?.trim() ?? '';
    if (n.isNotEmpty) return n.split(' ').first;
    final e = u.email ?? '';
    return e.contains('@') ? e.split('@').first : 'Player';
  }

  static Future<void> publish({required int streak, required int pct}) async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null || u.isAnonymous) return;
      final db = FirebaseFirestore.instance;
      final me = (await db.doc('users/${u.uid}').get()).data() ?? {};
      if (me['hideFromBoard'] == true) return;
      await db.doc('leaderboard/${u.uid}').set({
        'name': displayName(u),
        'photo': u.photoURL,
        'xp': (me['xp'] as num?)?.toInt() ?? 0,
        'streak': streak,
        'pct': pct,
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  static Future<void> setVisible(bool on, {int streak = 0, int pct = 0}) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || u.isAnonymous) return;
    final db = FirebaseFirestore.instance;
    await db.doc('users/${u.uid}').set({'hideFromBoard': !on}, SetOptions(merge: true));
    if (on) {
      await publish(streak: streak, pct: pct);
    } else {
      await db.doc('leaderboard/${u.uid}').delete();
    }
  }
}

/// The leaderboard card for the Profile tab: who is locked in, side by side.
class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final db = FirebaseFirestore.instance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.emoji_events_rounded, color: _orange),
          const SizedBox(width: 10),
          Expanded(child: Text('Leaderboard', style: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.w700, color: _ink))),
        ]),
        Text('Who is locked in. Ranked by XP.', style: GoogleFonts.lexend(fontSize: 12, color: _muted)),
        const SizedBox(height: 12),
        if (u == null || u.isAnonymous)
          Text('Sign in with GitHub or Google to join the leaderboard.', style: GoogleFonts.lexend(fontSize: 14, color: _muted))
        else ...[
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: db.doc('users/${u.uid}').snapshots(),
            builder: (context, s) {
              final hidden = s.data?.data()?['hideFromBoard'] == true;
              return Row(children: [
                Expanded(child: Text('Show me on the leaderboard', style: GoogleFonts.lexend(fontSize: 14, color: _ink))),
                Switch(value: !hidden, activeThumbColor: _orange, onChanged: (v) => Leaderboard.setVisible(v)),
              ]);
            },
          ),
          const SizedBox(height: 4),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('leaderboard').orderBy('xp', descending: true).limit(20).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Could not load the leaderboard.', style: GoogleFonts.lexend(fontSize: 13, color: _muted));
              }
              final docs = snap.data?.docs ?? const [];
              if (snap.connectionState == ConnectionState.waiting && docs.isEmpty) {
                return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: _orange)));
              }
              if (docs.isEmpty) {
                return Text('No one yet. Finish a habit to be the first.', style: GoogleFonts.lexend(fontSize: 13, color: _muted));
              }
              final top = ((docs.first.data()['xp'] as num?) ?? 1).toInt().clamp(1, 1 << 30);
              return Column(children: [
                for (var i = 0; i < docs.length; i++)
                  _Row(rank: i + 1, d: docs[i].data(), me: docs[i].id == u.uid, top: top),
              ]);
            },
          ),
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank, top;
  final Map<String, dynamic> d;
  final bool me;
  const _Row({required this.rank, required this.d, required this.me, required this.top});

  @override
  Widget build(BuildContext context) {
    final xp = (d['xp'] as num?)?.toInt() ?? 0;
    final streak = (d['streak'] as num?)?.toInt() ?? 0;
    final name = '${d['name'] ?? 'Player'}';
    final photo = d['photo'] as String?;
    final medal = rank == 1 ? const Color(0xFFE0A100) : rank == 2 ? const Color(0xFF9AA0A6) : rank == 3 ? const Color(0xFFB36B2E) : null;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: me ? _soft : Colors.transparent, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        SizedBox(
          width: 26,
          child: medal != null
              ? Icon(Icons.workspace_premium_rounded, color: medal, size: 24)
              : Text('$rank', textAlign: TextAlign.center, style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w600, color: _muted)),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 16,
          backgroundColor: _line,
          backgroundImage: photo != null ? NetworkImage(photo) : null,
          child: photo == null ? Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: GoogleFonts.lexend(fontSize: 13, color: _ink)) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(me ? '$name (you)' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: xp / top, minHeight: 6, backgroundColor: _line, valueColor: const AlwaysStoppedAnimation(_orange)),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$xp XP', style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_fire_department_rounded, size: 13, color: _orange),
            Text('$streak', style: GoogleFonts.lexend(fontSize: 11, color: _muted)),
          ]),
        ]),
      ]),
    );
  }
}
