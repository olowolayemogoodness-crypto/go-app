import 'package:flutter/material.dart';

import '../services/github.dart';
import '../theme/prefs.dart';
import 'common.dart';

/// The developer's habit card: a GitHub-style contribution heat-map, streak, and check button.
class GitHubCard extends StatefulWidget {
  final String user;
  final bool done;
  final String statusText;
  final VoidCallback onCheck;
  final VoidCallback? onOpen;
  const GitHubCard({super.key, required this.user, required this.done, required this.statusText, required this.onCheck, this.onOpen});
  @override
  State<GitHubCard> createState() => _GitHubCardState();
}

class _GitHubCardState extends State<GitHubCard> {
  List<GhDay>? _days;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _error = null);
    try {
      final d = await GithubService.contributions(widget.user, force: force);
      if (mounted) setState(() => _days = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load GitHub activity.');
    }
  }

  int _streak(List<GhDay> days) {
    var s = 0;
    var i = days.length - 1;
    if (i >= 0 && days[i].level == 0) i--; // today may not have a commit yet
    while (i >= 0 && days[i].level > 0) {
      s++;
      i--;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final days = _days;
    final n = DateTime.now();
    final needsPush = !widget.done &&
        days != null &&
        days.last.level == 0 &&
        days.last.date.year == n.year &&
        days.last.date.month == n.month &&
        days.last.date.day == n.day;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen,
      child: ChunkyCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.code_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Push a commit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('@${widget.user}', style: TextStyle(fontSize: 13, color: p.muted)),
            ]),
          ),
          if (widget.done) Icon(Icons.check_circle_rounded, color: p.teal, size: 28),
          if (widget.onOpen != null) Icon(Icons.chevron_right_rounded, color: p.muted),
        ]),
        const SizedBox(height: 14),
        if (_error != null)
          Row(children: [
            Expanded(child: Text(_error!, style: TextStyle(color: p.muted))),
            TextButton(onPressed: () => _load(force: true), child: const Text('Retry')),
          ])
        else if (days == null)
          const SizedBox(height: 90, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)))
        else ...[
          _HeatMap(days: days),
          const SizedBox(height: 10),
          Row(children: [
            _Pill(text: '${_streak(days)} day streak', color: p.sunSoft, fg: p.orange),
            const SizedBox(width: 8),
            _Pill(
                text: '${days.where((d) => d.level > 0).length} active days',
                color: p.mint,
                fg: p.mintInk),
          ]),
        ],
        if (needsPush)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('No commit yet today. Push something before midnight.',
                style: TextStyle(fontSize: 13, color: p.orange, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 14),
        if (widget.statusText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(widget.statusText, style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w600)),
          ),
        if (!widget.done) BigButton(label: 'Check GitHub', icon: Icons.refresh_rounded, onPressed: widget.onCheck),
      ]),
    ));
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color, fg;
  const _Pill({required this.text, required this.color, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      );
}

class _HeatMap extends StatelessWidget {
  final List<GhDay> days;
  const _HeatMap({required this.days});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final levels = [p.line, const Color(0xFFFFD79A), const Color(0xFFF7B24C), p.orange, const Color(0xFFB86A00)];
    // Group into weeks (columns) starting Sunday.
    final weeks = <List<GhDay?>>[];
    var col = List<GhDay?>.filled(7, null);
    for (final d in days) {
      final row = d.date.weekday % 7; // Sunday = 0
      if (row == 0 && col.any((x) => x != null)) {
        weeks.add(col);
        col = List<GhDay?>.filled(7, null);
      }
      col[row] = d;
    }
    weeks.add(col);
    return LayoutBuilder(builder: (context, c) {
      const gap = 3.0;
      final shown = weeks.length > 22 ? weeks.sublist(weeks.length - 22) : weeks;
      final cell = ((c.maxWidth - gap * (shown.length - 1)) / shown.length).clamp(6.0, 14.0);
      return Semantics(
        label: 'GitHub contribution history for the last ${shown.length} weeks',
        child: ExcludeSemantics(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var w = 0; w < shown.length; w++) ...[
              if (w > 0) const SizedBox(width: gap),
              Column(children: [
                for (var r = 0; r < 7; r++) ...[
                  if (r > 0) const SizedBox(height: gap),
                  Container(
                    width: cell,
                    height: cell,
                    decoration: BoxDecoration(
                      color: shown[w][r] == null ? Colors.transparent : levels[shown[w][r]!.level.clamp(0, 4)],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ]),
            ],
          ]),
        ),
      );
    });
  }
}

/// XP chip for the top of Home.
class XpChip extends StatelessWidget {
  final int xp;
  const XpChip({super.key, required this.xp});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Semantics(
      label: '$xp experience points',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bolt_rounded, size: 18, color: p.sunSoft),
          const SizedBox(width: 4),
          Text('$xp XP', style: TextStyle(color: p.sunSoft, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
      ),
    );
  }
}
