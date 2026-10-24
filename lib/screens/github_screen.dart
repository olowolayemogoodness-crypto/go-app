import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/github.dart';
import '../services/reminders.dart';

const _bg = Color(0xFFFFF9F2);
const _ink = Color(0xFF1B1B1F);
const _muted = Color(0xFF6C6C75);
const _orange = Color(0xFFE08813);
const _soft = Color(0xFFFFF0DA);
const _line = Color(0xFFE9DFD2);
const _green = Color(0xFF2E9E6B);
const _levels = [Color(0xFFEFE6DA), Color(0xFFFFD79A), Color(0xFFF7B24C), Color(0xFFE08813), Color(0xFFB86A00)];

class _Push {
  final String text, url;
  const _Push(this.text, this.url);
}

/// Full GitHub screen: year heat-map, streaks, today's pushes and the daily reminder.
class GithubScreen extends StatefulWidget {
  final String user;
  final bool done;
  final VoidCallback onCheck;
  const GithubScreen({super.key, required this.user, required this.done, required this.onCheck});
  @override
  State<GithubScreen> createState() => _GithubScreenState();
}

class _GithubScreenState extends State<GithubScreen> {
  List<GhDay>? _days;
  List<_Push> _today = [];
  String? _error;
  String? _remind; // "HH:mm" when on
  String _bestTime = 'evening';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await GithubService.contributions(widget.user, force: true);
      if (mounted) setState(() => _days = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load GitHub activity. Check the username and your connection.');
    }
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final s = await FirebaseFirestore.instance.doc('users/$uid').get();
      _bestTime = '${(s.data()?['profile'] as Map?)?['bestTime'] ?? 'evening'}';
    } catch (_) {}
    _remind = await Reminders.saved();
    if (mounted) setState(() {});
    _loadToday();
  }

  Future<void> _loadToday() async {
    try {
      final r = await http.get(
          Uri.parse('https://api.github.com/users/${Uri.encodeComponent(widget.user)}/events/public?per_page=100'),
          headers: {'accept': 'application/vnd.github+json'});
      if (r.statusCode != 200) return;
      final now = DateTime.now();
      final out = <_Push>[];
      for (final e in jsonDecode(r.body) as List) {
        if (e['type'] != 'PushEvent') continue;
        final at = DateTime.parse('${e['created_at']}').toLocal();
        if (at.year != now.year || at.month != now.month || at.day != now.day) continue;
        final repo = '${e['repo']?['name']}';
        final commits = (e['payload']?['commits'] as List?) ?? const [];
        if (commits.isEmpty) {
          out.add(_Push('Pushed to $repo', 'https://github.com/$repo'));
        } else {
          for (final c in commits) {
            final msg = '${c['message'] ?? 'commit'}'.split('\n').first;
            out.add(_Push(msg, 'https://github.com/$repo/commit/${c['sha']}'));
          }
        }
      }
      if (mounted) setState(() => _today = out);
    } catch (_) {}
  }

  String get _defaultTime => const {'morning': '09:00', 'afternoon': '14:00', 'evening': '19:00', 'night': '22:00'}[_bestTime] ?? '19:00';

  Future<void> _toggleRemind(bool on) async {
    if (!on) {
      await Reminders.disable();
      setState(() => _remind = null);
      return;
    }
    final ok = await Reminders.enable(_defaultTime, widget.user);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notifications are off. Allow them for GO in Settings to get reminders.')));
      return;
    }
    setState(() => _remind = _defaultTime);
  }

  Future<void> _pickTime() async {
    final cur = (_remind ?? _defaultTime).split(':');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(cur[0]), minute: int.parse(cur[1])));
    if (t == null) return;
    final hhmm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final ok = await Reminders.enable(hhmm, widget.user);
    if (mounted && ok) setState(() => _remind = hhmm);
  }

  ({int current, int longest, int active, int week}) _stats(List<GhDay> days) {
    var cur = 0;
    var i = days.length - 1;
    if (i >= 0 && days[i].level == 0) i--;
    while (i >= 0 && days[i].level > 0) {
      cur++;
      i--;
    }
    var longest = 0, run = 0;
    for (final d in days) {
      run = d.level > 0 ? run + 1 : 0;
      if (run > longest) longest = run;
    }
    final last7 = days.length > 7 ? days.sublist(days.length - 7) : days;
    return (current: cur, longest: longest, active: days.where((d) => d.level > 0).length, week: last7.where((d) => d.level > 0).length);
  }

  bool _committedToday(List<GhDay> days) {
    if (_today.isNotEmpty || widget.done) return true;
    final n = DateTime.now();
    final last = days.last;
    return last.date.year == n.year && last.date.month == n.month && last.date.day == n.day && last.level > 0;
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    final committed = days != null && _committedToday(days);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: Text('GitHub', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, color: _ink)),
        actions: [IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
          Row(children: [
            CircleAvatar(radius: 26, backgroundColor: _line, backgroundImage: NetworkImage('https://github.com/${widget.user}.png?size=120')),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('@${widget.user}', style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.w700, color: _ink)),
                Text('Code a little every day.', style: GoogleFonts.lexend(fontSize: 13, color: _muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          if (days != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: committed ? const Color(0xFFF1FAF5) : _soft, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(committed ? Icons.check_circle_rounded : Icons.schedule_rounded, color: committed ? _green : _orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    committed ? 'You have coded today. Streak safe.' : 'No commit yet today. Push something before midnight.',
                    style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w500, color: _ink),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: GoogleFonts.lexend(color: _muted))
          else if (days == null)
            const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: _orange)))
          else ...[
            Builder(builder: (_) {
              final s = _stats(days);
              Widget tile(String v, String l) => Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line, width: 1.5)),
                      child: Column(children: [
                        Text(v, style: GoogleFonts.fredoka(fontSize: 26, fontWeight: FontWeight.w700, color: _orange)),
                        Text(l, textAlign: TextAlign.center, style: GoogleFonts.lexend(fontSize: 11, color: _muted)),
                      ]),
                    ),
                  );
              return Row(children: [
                tile('${s.current}', 'current\nstreak'),
                const SizedBox(width: 8),
                tile('${s.longest}', 'longest\nstreak'),
                const SizedBox(width: 8),
                tile('${s.week}/7', 'this\nweek'),
                const SizedBox(width: 8),
                tile('${s.active}', 'active days\nthis year'),
              ]);
            }),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line, width: 1.5)),
              child: _YearMap(days: days),
            ),
          ],
          const SizedBox(height: 20),
          Text('Today', style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 8),
          if (_today.isEmpty)
            Text('No pushes found yet today.', style: GoogleFonts.lexend(fontSize: 13, color: _muted))
          else
            for (final p in _today)
              InkWell(
                onTap: () => launchUrl(Uri.parse(p.url), mode: LaunchMode.externalApplication),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.commit_rounded, size: 20, color: _orange),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.lexend(fontSize: 14, color: _ink))),
                  ]),
                ),
              ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line, width: 1.5)),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.notifications_active_outlined, color: _orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Daily commit reminder', style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
                    Text(_remind == null ? 'Off' : 'Every day at $_remind', style: GoogleFonts.lexend(fontSize: 12, color: _muted)),
                  ]),
                ),
                Switch(value: _remind != null, activeThumbColor: _orange, onChanged: _toggleRemind),
              ]),
              if (_remind != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _pickTime, child: const Text('Change time')),
                ),
            ]),
          ),
          const SizedBox(height: 20),
          if (!widget.done)
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onCheck();
                },
                icon: const Icon(Icons.verified_rounded),
                label: Text('Check GitHub for today', style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(backgroundColor: _ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Full-year heat-map with month labels, scrolls sideways, opens at the latest week.
class _YearMap extends StatefulWidget {
  final List<GhDay> days;
  const _YearMap({required this.days});
  @override
  State<_YearMap> createState() => _YearMapState();
}

class _YearMapState extends State<_YearMap> {
  final _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) _sc.jumpTo(_sc.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weeks = <List<GhDay?>>[];
    var col = List<GhDay?>.filled(7, null);
    for (final d in widget.days) {
      final row = d.date.weekday % 7;
      if (row == 0 && col.any((x) => x != null)) {
        weeks.add(col);
        col = List<GhDay?>.filled(7, null);
      }
      col[row] = d;
    }
    weeks.add(col);
    const cell = 12.0, gap = 3.0;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    int? lastMonth;
    return Semantics(
      label: 'GitHub contribution history for the last year',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          controller: _sc,
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var w = 0; w < weeks.length; w++) ...[
              if (w > 0) const SizedBox(width: gap),
              Builder(builder: (_) {
                final first = weeks[w].firstWhere((x) => x != null, orElse: () => null);
                String label = '';
                if (first != null && first.date.month != lastMonth) {
                  lastMonth = first.date.month;
                  label = months[first.date.month - 1];
                }
                return Column(children: [
                  SizedBox(width: cell, height: 16, child: OverflowBox(maxWidth: 40, alignment: Alignment.centerLeft, child: Text(label, style: GoogleFonts.lexend(fontSize: 10, color: _muted)))),
                  for (var r = 0; r < 7; r++) ...[
                    if (r > 0) const SizedBox(height: gap),
                    Container(
                      width: cell,
                      height: cell,
                      decoration: BoxDecoration(
                        color: weeks[w][r] == null ? Colors.transparent : _levels[weeks[w][r]!.level.clamp(0, 4)],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ]);
              }),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Less ', style: GoogleFonts.lexend(fontSize: 10, color: _muted)),
          for (final c in _levels)
            Container(margin: const EdgeInsets.only(left: 3), width: 11, height: 11, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          Text('  More', style: GoogleFonts.lexend(fontSize: 10, color: _muted)),
        ]),
      ]),
    );
  }
}
