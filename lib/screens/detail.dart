import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


const _done = {'passed', 'passed_by_partner'};
const _bg = Color(0xFFFFF9F2);
const _ink = Color(0xFF1B1B1F);
const _muted = Color(0xFF6C6C75);
const _orange = Color(0xFFE08813);
const _soft = Color(0xFFFFF0DA);
const _line = Color(0xFFE9DFD2);
const _green = Color(0xFF2E9E6B);

/// Program details: the premium, the partner, your habits and the 30-day grid.
class DetailScreen extends StatelessWidget {
  final String pledgeId;
  const DetailScreen({super.key, required this.pledgeId});

  int _today(Map<String, dynamic> p) {
    try {
      final start = DateTime.parse('${p['startDate']}T00:00:00Z');
      final off = (p['tzOffsetMin'] as num).toInt();
      final n = DateTime.now().toUtc().add(Duration(minutes: off));
      return DateTime.utc(n.year, n.month, n.day).difference(start).inDays + 1;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fs.doc('pledges/$pledgeId').snapshots(),
      builder: (context, ps) {
        final p = ps.data?.data();
        if (p == null) return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator(color: _orange)));
        final days = (p['days'] as num).toInt();
        final acts = (p['activities'] as List).cast<Map>();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fs.collection('pledges/$pledgeId/acts').snapshots(),
          builder: (context, as) {
            final doneBy = <int, int>{};
            for (final d in as.data?.docs ?? const []) {
              final x = d.data();
              if (_done.contains(x['status'])) {
                final k = (x['day'] as num).toInt();
                doneBy[k] = (doneBy[k] ?? 0) + 1;
              }
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: fs.collection('pledges/$pledgeId/days').snapshots(),
              builder: (context, ds) {
                final skipped = {for (final d in ds.data?.docs ?? const []) int.tryParse(d.id) ?? 0};
                final today = _today(p);
                Widget stat(String v, String l) => Expanded(
                      child: Column(children: [
                        Text(v, style: GoogleFonts.fredoka(fontSize: 26, fontWeight: FontWeight.w700, color: _orange)),
                        Text(l, textAlign: TextAlign.center, style: GoogleFonts.lexend(fontSize: 11, color: _muted)),
                      ]),
                    );
                return Scaffold(
                  backgroundColor: _bg,
                  appBar: AppBar(
                    backgroundColor: _bg,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: _ink),
                    title: Text('Program details', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, color: _ink)),
                  ),
                  body: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(99)),
                              child: Text('Simulated fee. No real money.',
                                  style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600, color: _orange)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(22)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Your commitment fee', style: GoogleFonts.lexend(fontSize: 13, color: Colors.white70)),
                              Text('${p['premium']} coins', style: GoogleFonts.fredoka(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(height: 6),
                              Text('Follow through and all ${p['refundAmount']} comes back.',
                                  style: GoogleFonts.lexend(fontSize: 14, color: const Color(0xFFFFD79A))),
                            ]),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line, width: 1.5)),
                            child: Row(children: [
                              stat('${p['gracePasses']}', 'grace passes\nleft'),
                              stat('${doneBy.values.fold<int>(0, (a, b) => a + b)}', 'habits\ndone'),
                              stat('${skipped.length}', 'days\nskipped'),
                            ]),
                          ),
                          const SizedBox(height: 14),
                          Row(children: [
                            const Icon(Icons.handshake_outlined, color: _orange),
                            const SizedBox(width: 10),
                            Text('Partner: ', style: GoogleFonts.lexend(fontSize: 15, color: _muted)),
                            Text('${p['partnerName']}', style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
                          ]),
                          const SizedBox(height: 22),
                          Text('Your habits', style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
                          const SizedBox(height: 8),
                          for (final a in acts)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(children: [
                                Icon(a['kind'] == 'github' ? Icons.code_rounded : Icons.photo_camera_outlined, size: 20, color: _orange),
                                const SizedBox(width: 12),
                                Expanded(child: Text('${a['title']}', style: GoogleFonts.lexend(fontSize: 15, color: _ink))),
                                Text(a['kind'] == 'github' ? 'GitHub' : 'Camera',
                                    style: GoogleFonts.lexend(fontSize: 12, color: _muted)),
                              ]),
                            ),
                          const SizedBox(height: 22),
                          Text('Your 30 days', style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
                          const SizedBox(height: 10),
                          GridView.count(
                            crossAxisCount: 6,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            children: [
                              for (var d = 1; d <= days; d++) _DayCell(day: d, n: doneBy[d] ?? 0, total: acts.length, skipped: skipped.contains(d), isToday: d == today, future: d > today),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(spacing: 14, runSpacing: 6, children: [
                            _key(_green, 'All done'),
                            _key(_orange, 'Some done'),
                            _key(const Color(0xFF8E8E99), 'Skipped (grace)'),
                            _key(_line, 'Not yet'),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _key(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(t, style: GoogleFonts.lexend(fontSize: 12, color: _muted)),
      ]);
}

class _DayCell extends StatelessWidget {
  final int day, n, total;
  final bool skipped, isToday, future;
  const _DayCell({required this.day, required this.n, required this.total, required this.skipped, required this.isToday, required this.future});

  @override
  Widget build(BuildContext context) {
    Color bg = _line;
    Color fg = _muted;
    if (skipped) {
      bg = const Color(0xFF8E8E99);
      fg = Colors.white;
    } else if (total > 0 && n >= total) {
      bg = _green;
      fg = Colors.white;
    } else if (n > 0) {
      bg = _orange;
      fg = Colors.white;
    } else if (!future && !isToday) {
      bg = const Color(0xFFF3D9D5); // a missed day
    }
    return Semantics(
      label: skipped ? 'Day $day: skipped with grace pass' : 'Day $day: $n of $total done',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: isToday ? Border.all(color: _ink, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: Text('$day', style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}
