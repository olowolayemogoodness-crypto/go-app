import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/api.dart';
import '../theme/prefs.dart';
import '../widgets/common.dart';
import '../widgets/github_widget.dart';
import '../widgets/habit_cards.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'checkin.dart';
import 'github_screen.dart';
import 'detail.dart';

const _done = {'passed', 'passed_by_partner'};

/// Home: the big battery, streak, overall %, grace passes and today's activity list.
class TodayScreen extends StatefulWidget {
  final String pledgeId;
  const TodayScreen({super.key, required this.pledgeId});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Timer? _tick;
  Map<String, dynamic>? _stats;
  int _graceLeft = -1;
  bool _busy = false;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _sync();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _sync() async {
    try {
      final r = await Api.sync(widget.pledgeId);
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(r['stats'] as Map);
        _graceLeft = (r['gracePasses'] as num).toInt();
      });
    } catch (_) {}
  }

  int _dayOf(Map<String, dynamic> p) {
    final start = DateTime.parse('${p['startDate']}T00:00:00Z');
    final off = (p['tzOffsetMin'] as num).toInt();
    final nowLocal = DateTime.now().toUtc().add(Duration(minutes: off));
    final today = DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day);
    return today.difference(start).inDays + 1;
  }

  String _left(Map<String, dynamic> p) {
    final off = (p['tzOffsetMin'] as num).toInt();
    final nowLocal = DateTime.now().toUtc().add(Duration(minutes: off));
    final end = DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day + 1);
    final d = end.difference(nowLocal);
    return '${d.inHours}h ${d.inMinutes % 60}m left today';
  }

  Future<void> _grace() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Use a grace pass?'),
        content: const Text('Today is skipped with no penalty. It does not count against your 90%.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Use pass')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await Api.useGrace(widget.pledgeId);
      await _sync();
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fs.doc('pledges/${widget.pledgeId}').snapshots(),
      builder: (context, ps) {
        final p = ps.data?.data();
        if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        // When a program ends, HomeGate swaps to the result screen.
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fs.collection('pledges/${widget.pledgeId}/acts').snapshots(),
          builder: (context, as) {
            final days = (p['days'] as num).toInt();
            final day = _dayOf(p).clamp(1, days);
            final status = <String, String>{};
            for (final d in as.data?.docs ?? const []) {
              final x = d.data();
              if ((x['day'] as num?)?.toInt() == day) {
                status[x['actId'] as String] = (x['status'] as String?) ?? 'pending';
              }
            }
            return _scaffold(context, p, day, days, status);
          },
        );
      },
    );
  }

  Widget _scaffold(BuildContext context, Map<String, dynamic> p, int day, int days,
      Map<String, String> status) {
    final pal = Pal.of(context);
    final t = Theme.of(context).textTheme;
    final acts = (p['activities'] as List).cast<Map>();
    final total = acts.length;
    final doneN = acts.where((a) => _done.contains(status[a['id']])).length;
    final pct = total == 0 ? 0 : (100 * doneN / total).round();
    final grace = _graceLeft >= 0 ? _graceLeft : (p['gracePasses'] as num).toInt();
    final streak = _stats?['streak'] ?? 0;
    final overall = _stats == null ? '-' : '${_stats!['overallPct']}%';
    final premium = (p['premium'] as num).toInt();
    final refund = (p['refundAmount'] as num).toInt();
    final summary = 'Day $day of $days. $doneN of $total activities done. Battery $pct percent. '
        'Streak $streak days. ${_left(p)}.';

    return PageShell(
      title: 'GO',
      showBack: false,
      actions: [
        IconButton(
          tooltip: 'Program details',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => DetailScreen(pledgeId: widget.pledgeId))),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Semantics(header: true, child: Text('Today', style: t.headlineMedium)),
              _xp(),
              Text('Day $day of $days', style: TextStyle(fontWeight: FontWeight.w600, color: pal.muted)),
            ],
          ),
          const SizedBox(height: 14),
          ChunkyCard(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BatteryMeter(done: doneN, total: total),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$pct%', style: t.displaySmall),
                    Flexible(
                      child: Text(
                          doneN >= total ? 'Fully charged!' : '$doneN of $total done · ${total - doneN} to full charge',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: pal.muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_left(p), style: TextStyle(color: pal.muted, fontSize: 13)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await _tts.stop();
                      await _tts.speak(summary);
                    },
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Read aloud'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: StatTile(value: '$streak', label: 'day streak', color: pal.sunSoft, textColor: pal.onSun)),
            const SizedBox(width: 10),
            Expanded(
                child: StatTile(
                    value: overall, label: 'overall (need 90%)', color: pal.mint, textColor: pal.mintInk)),
            const SizedBox(width: 10),
            Expanded(child: StatTile(value: '$grace', label: 'grace passes', color: pal.peach, textColor: pal.onSun)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: pal.ink, borderRadius: BorderRadius.circular(16)),
            child: Text(
              'Finish all $days days at 90% or more and get $refund of your $premium premium back (simulated).',
              style: TextStyle(color: pal.sunSoft, fontWeight: FontWeight.w500, height: 1.4),
            ),
          ),
          const SizedBox(height: 22),
          Text('Your list for today', style: t.titleLarge),
          const SizedBox(height: 10),
          for (final a in acts) _habitCard(context, p, a, day, status[a['id']] ?? 'pending'),
          if (doneN == 0 && grace > 0)
            TextButton(
              onPressed: _busy ? null : _grace,
              child: const Text('Not today? Use a grace pass'),
            ),
        ],
      ),
    );
  }

  Widget _xp() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.doc('users/$uid').snapshots(),
      builder: (context, s) => XpChip(xp: (s.data?.data()?['xp'] as num?)?.toInt() ?? 0),
    );
  }

  Widget _habitCard(BuildContext context, Map<String, dynamic> p, Map a, int day, String st) {
    if (a['kind'] == 'github' && '${p['githubUser'] ?? ''}'.isNotEmpty) {
      final isDone = _done.contains(st);
      final waiting = st == 'pending_partner' || st == 'appealed';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GitHubCard(
          user: '${p['githubUser']}',
          done: isDone,
          statusText: waiting ? 'Waiting for partner' : (st == 'failed' ? 'Not confirmed' : ''),
          onOpen: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => GithubScreen(
                        user: '${p['githubUser']}',
                        done: isDone,
                        onCheck: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CheckInScreen(
                                      pledgeId: widget.pledgeId,
                                      actId: a['id'] as String,
                                      title: '${a['title']}',
                                      kind: 'github',
                                      day: day,
                                      partnerName: '${p['partnerName']}')));
                          _sync();
                        },
                      ))),
          onCheck: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CheckInScreen(
                        pledgeId: widget.pledgeId,
                        actId: a['id'] as String,
                        title: '${a['title']}',
                        kind: 'github',
                        day: day,
                        partnerName: '${p['partnerName']}')));
            _sync();
          },
        ),
      );
    }
    return HabitCard(
      title: '${a['title']}',
      status: st,
      onCheck: () async {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CheckInScreen(
                    pledgeId: widget.pledgeId,
                    actId: a['id'] as String,
                    title: '${a['title']}',
                    kind: '${a['kind']}',
                    day: day,
                    partnerName: '${p['partnerName']}')));
        _sync();
      },
    );
  }

  // ignore: unused_element
  Widget _row(BuildContext context, Map<String, dynamic> p, Map a, int day, String st) {
    final pal = Pal.of(context);
    final isDone = _done.contains(st);
    final waiting = st == 'pending_partner' || st == 'appealed';
    String tag = '';
    if (isDone) tag = st == 'passed_by_partner' ? 'Confirmed' : 'Done';
    if (waiting) tag = 'Waiting for partner';
    if (st == 'failed') tag = 'Not confirmed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ChunkyCard(
        shadow: !isDone,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? pal.teal : Colors.transparent,
              border: isDone ? null : Border.all(color: pal.primary, width: 2.5),
            ),
            child: isDone ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['title']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (tag.isNotEmpty) Text(tag, style: TextStyle(fontSize: 13, color: pal.mintInk, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (!isDone)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CheckInScreen(
                            pledgeId: widget.pledgeId,
                            actId: a['id'] as String,
                            title: '${a['title']}',
                            kind: '${a['kind']}',
                            day: day,
                            partnerName: '${p['partnerName']}')));
                _sync();
              },
              child: Text(waiting ? 'Open' : (a['kind'] == 'github' ? 'Check GitHub' : 'Check in')),
            ),
        ]),
      ),
    );
  }
}
