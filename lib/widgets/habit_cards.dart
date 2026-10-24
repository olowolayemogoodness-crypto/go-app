import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _ink = Color(0xFF1B1B1F);
const _muted = Color(0xFF6C6C75);
const _orange = Color(0xFFE08813);
const _soft = Color(0xFFFFF0DA);
const _line = Color(0xFFE9DFD2);
const _green = Color(0xFF2E9E6B);

enum HabitType { screen, workout, study, read, sleep, money, tidy, other }

HabitType habitTypeOf(String title) {
  final t = title.toLowerCase();
  if (t.startsWith('screen time')) return HabitType.screen;
  if (t.startsWith('workout')) return HabitType.workout;
  if (t.startsWith('study')) return HabitType.study;
  if (t.startsWith('read')) return HabitType.read;
  if (t.startsWith('phone down')) return HabitType.sleep;
  if (t.contains('spending')) return HabitType.money;
  if (t.startsWith('tidy')) return HabitType.tidy;
  return HabitType.other;
}

class _Look {
  final IconData icon;
  final Color color;
  final String big, unit, hint, button;
  const _Look(this.icon, this.color, this.big, this.unit, this.hint, this.button);
}

_Look _lookFor(HabitType t, String title) {
  final n = RegExp(r'\d+').firstMatch(title)?.group(0) ?? '';
  switch (t) {
    case HabitType.screen:
      return _Look(Icons.phone_iphone_rounded, _orange, '${n}h', 'limit', 'Stay under it for an XP boost', 'Add screenshot');
    case HabitType.workout:
      return _Look(Icons.local_fire_department_rounded, const Color(0xFFE5532D), n, 'min', 'Show your workout on camera', 'Check in');
    case HabitType.study:
      return _Look(Icons.menu_book_rounded, const Color(0xFF4A6FE3), n, 'min', 'Show your study session', 'Check in');
    case HabitType.read:
      return _Look(Icons.auto_stories_rounded, const Color(0xFF8A5BD6), n, 'pages', 'Show the page you reached', 'Check in');
    case HabitType.sleep:
      final m = RegExp(r'by (.+)$').firstMatch(title)?.group(1) ?? '11pm';
      return _Look(Icons.bedtime_rounded, const Color(0xFF3E4A89), m, 'bedtime', 'Show your phone put down', 'Check in');
    case HabitType.money:
      return const _Look(Icons.savings_rounded, _green, '1', 'log', 'Show today\'s spending record', 'Check in');
    case HabitType.tidy:
      return _Look(Icons.checklist_rounded, const Color(0xFF1F9AA8), n, 'min', 'Show your tidy desk', 'Check in');
    case HabitType.other:
      return const _Look(Icons.bolt_rounded, _orange, '', '', '', 'Check in');
  }
}

/// A home-screen card with its own look for each kind of habit.
class HabitCard extends StatelessWidget {
  final String title;
  final String status; // pending, passed, passed_by_partner, pending_partner, appealed, failed
  final VoidCallback onCheck;
  const HabitCard({super.key, required this.title, required this.status, required this.onCheck});

  @override
  Widget build(BuildContext context) {
    final type = habitTypeOf(title);
    final look = _lookFor(type, title);
    final done = status == 'passed' || status == 'passed_by_partner';
    final waiting = status == 'pending_partner' || status == 'appealed';
    final tag = done
        ? (status == 'passed_by_partner' ? 'Confirmed by partner' : 'Done')
        : waiting
            ? 'Waiting for partner'
            : status == 'failed'
                ? 'Not confirmed'
                : look.hint;
    final color = done ? _green : look.color;
    final ring = _Ring(
      value: done ? 1 : (waiting ? 0.5 : 0),
      color: color,
      child: done
          ? Icon(Icons.check_rounded, color: color, size: 34)
          : look.big.isEmpty
              ? Icon(look.icon, color: color, size: 30)
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(look.big,
                      style: GoogleFonts.lexend(fontSize: look.big.length > 3 ? 15 : 22, fontWeight: FontWeight.w700, color: _ink)),
                  Text(look.unit, style: GoogleFonts.lexend(fontSize: 10, color: _muted)),
                ]),
    );
    return Semantics(
      container: true,
      label: '$title. $tag',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? const Color(0xFFF1FAF5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: done ? _green.withOpacity(0.4) : _line, width: 1.5),
        ),
        child: Row(children: [
          SizedBox(width: 78, height: 78, child: ring),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(look.icon, size: 16, color: color),
                const SizedBox(width: 6),
                if (type == HabitType.screen && !done)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(99)),
                    child: Text('x1.5 XP', style: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.w700, color: _orange)),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(title, style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600, color: _ink, height: 1.2)),
              const SizedBox(height: 2),
              Text(tag, style: GoogleFonts.lexend(fontSize: 12, color: done ? _green : _muted)),
              if (!done) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: onCheck,
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(waiting ? 'Open' : look.button, style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double value;
  final Color color;
  final Widget child;
  const _Ring({required this.value, required this.color, required this.child});
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _RingPainter(value, color),
        child: Center(child: child),
      );
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  _RingPainter(this.value, this.color);
  @override
  void paint(Canvas canvas, Size s) {
    const w = 8.0;
    final r = Rect.fromLTWH(w / 2, w / 2, s.width - w, s.height - w);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.15);
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    if (value > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.value != value || o.color != color;
}
