import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/prefs.dart';
import 'home.dart';

const Color _bg = Color(0xFFFFF9F2);
const Color _ink = Color(0xFF1B1B1F);
const Color _muted = Color(0xFF6C6C75);
const Color _orange = Color(0xFFE08813);
const Color _orangeSoft = Color(0xFFFFF0DA);
const Color _line = Color(0xFFE9DFD2);

/// After sign-in: new users answer the questionnaire once, everyone else goes home.
class PostAuthGate extends StatelessWidget {
  const PostAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(backgroundColor: _bg);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.doc('users/$uid').snapshots(),
      builder: (context, snap) {
        // If the profile can't be read, don't trap the user on a blank screen.
        if (snap.hasError) return const HomeGate();
        if (!snap.hasData) return const Scaffold(backgroundColor: _bg);
        if (snap.data!.data()?['onboarded'] == true) return const HomeGate();
        return const OnboardingScreen();
      },
    );
  }
}

class _Opt {
  final String value, label;
  final IconData icon;
  const _Opt(this.value, this.label, this.icon);
}

class _Q {
  final String id, title, sub;
  final List<_Opt> opts;
  const _Q(this.id, this.title, this.sub, this.opts);
}

const _questions = <_Q>[
  _Q('focus', 'What do you want to fix first?', 'Pick the one that would change your week the most.', [
    _Opt('coding', 'Coding consistency', Icons.code_rounded),
    _Opt('sleep', 'Sleep', Icons.bedtime_outlined),
    _Opt('exercise', 'Exercise', Icons.fitness_center_rounded),
    _Opt('learning', 'Learning', Icons.menu_book_outlined),
    _Opt('money', 'Money habits', Icons.savings_outlined),
    _Opt('admin', 'Life admin', Icons.checklist_rounded),
  ]),
  _Q('bestTime', 'When do you work best?', 'We will nudge you at the right time.', [
    _Opt('morning', 'Morning', Icons.wb_sunny_outlined),
    _Opt('afternoon', 'Afternoon', Icons.light_mode_outlined),
    _Opt('evening', 'Evening', Icons.wb_twilight_rounded),
    _Opt('night', 'Late night', Icons.nightlight_outlined),
  ]),
  _Q('hours', 'How long do you code or study each day?', 'An honest guess is fine.', [
    _Opt('<1', 'Under 1 hour', Icons.timelapse_rounded),
    _Opt('1-2', '1 to 2 hours', Icons.timelapse_rounded),
    _Opt('3-5', '3 to 5 hours', Icons.timelapse_rounded),
    _Opt('6+', '6 hours or more', Icons.timelapse_rounded),
  ]),
  _Q('derail', 'What usually derails you?', 'No judgement. This shapes your plan.', [
    _Opt('procrastination', 'I put things off', Icons.hourglass_bottom_rounded),
    _Opt('scrolling', 'Phone and scrolling', Icons.smartphone_rounded),
    _Opt('burnout', 'I burn out', Icons.battery_alert_rounded),
    _Opt('noplan', 'I have no plan', Icons.explore_off_outlined),
  ]),
  _Q('streak', 'Longest streak you have ever kept?', 'Be honest, it helps us set the bar.', [
    _Opt('0', 'Never kept one', Icons.flag_outlined),
    _Opt('1-7', 'Up to a week', Icons.local_fire_department_outlined),
    _Opt('8-21', '1 to 3 weeks', Icons.local_fire_department_outlined),
    _Opt('22+', 'Over 3 weeks', Icons.local_fire_department_rounded),
  ]),
  _Q('habits', 'How many daily habits to start with?', 'Fewer is easier. You can add more later.', [
    _Opt('1', '1 habit', Icons.looks_one_outlined),
    _Opt('2', '2 habits', Icons.looks_two_outlined),
    _Opt('3', '3 habits', Icons.looks_3_outlined),
    _Opt('4', '4 habits', Icons.looks_4_outlined),
    _Opt('5', '5 habits', Icons.looks_5_outlined),
  ]),
];

/// Turns the answers into starter activities for the first 30-day program.
List<Map<String, String>> _suggest(Map<String, String> a) {
  const byFocus = {
    'coding': {'title': 'Push a commit', 'kind': 'github'},
    'sleep': {'title': 'Phone down by 11pm', 'kind': 'camera'},
    'exercise': {'title': 'Workout 20 minutes', 'kind': 'camera'},
    'learning': {'title': 'Study 30 minutes', 'kind': 'camera'},
    'money': {'title': 'Log today\'s spending', 'kind': 'camera'},
    'admin': {'title': 'Tidy desk for 10 minutes', 'kind': 'camera'},
  };
  const pool = [
    {'title': 'Push a commit', 'kind': 'github'},
    {'title': 'Workout 20 minutes', 'kind': 'camera'},
    {'title': 'Study 30 minutes', 'kind': 'camera'},
    {'title': 'Read 20 pages', 'kind': 'camera'},
    {'title': 'Tidy desk for 10 minutes', 'kind': 'camera'},
  ];
  final n = (int.tryParse(a['habits'] ?? '') ?? 3).clamp(1, 5);
  final out = <Map<String, String>>[Map<String, String>.from(byFocus[a['focus']] ?? pool.first)];
  for (final p in pool) {
    if (out.length >= n) break;
    if (out.any((o) => o['title'] == p['title'])) continue;
    out.add(Map<String, String>.from(p));
  }
  return out;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _forward = true;
  bool _saving = false;
  final Map<String, String> _answers = {};

  Future<void> _pick(String value) async {
    final q = _questions[_step];
    setState(() => _answers[q.id] = value);
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    if (_step < _questions.length - 1) {
      setState(() {
        _forward = true;
        _step++;
      });
    } else {
      await _finish();
    }
  }

  void _back() {
    if (_step == 0 || _saving) return;
    setState(() {
      _forward = false;
      _step--;
    });
  }

  Future<void> _finish() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.doc('users/$uid').set({
        'onboarded': true,
        'profile': {
          ..._answers,
          'suggested': _suggest(_answers),
          'completedAtMs': DateTime.now().millisecondsSinceEpoch,
        },
      }, SetOptions(merge: true));
      // PostAuthGate listens to this document and moves on by itself.
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your answers. Check your connection and try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_step];
    final reduce = prefs.reduceMotionFor(context);
    final progress = (_step + 1) / _questions.length;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: _step == 0
                          ? null
                          : IconButton(
                              tooltip: 'Back',
                              onPressed: _back,
                              icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                            ),
                    ),
                    Expanded(
                      child: Semantics(
                        label: 'Question ${_step + 1} of ${_questions.length}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: reduce ? Duration.zero : const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => LinearProgressIndicator(
                              value: v,
                              minHeight: 8,
                              backgroundColor: _line,
                              valueColor: const AlwaysStoppedAnimation(_orange),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ]),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _saving
                        ? Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const CircularProgressIndicator(color: _orange),
                              const SizedBox(height: 16),
                              Text('Building your plan...', style: GoogleFonts.lexend(fontSize: 16, color: _muted)),
                            ]),
                          )
                        : AnimatedSwitcher(
                            duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
                            transitionBuilder: (child, anim) {
                              final incoming = child.key == ValueKey(_step);
                              final dx = (incoming ? 1.0 : -1.0) * (_forward ? 1 : -1) * 0.12;
                              return FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim),
                                  child: child,
                                ),
                              );
                            },
                            child: _QuestionView(
                              key: ValueKey(_step),
                              q: q,
                              selected: _answers[q.id],
                              onPick: _pick,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  final _Q q;
  final String? selected;
  final ValueChanged<String> onPick;
  const _QuestionView({super.key, required this.q, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(q.title,
                style: GoogleFonts.fredoka(fontSize: 32, height: 1.1, fontWeight: FontWeight.w700, color: _ink)),
          ),
          const SizedBox(height: 8),
          Text(q.sub, style: GoogleFonts.lexend(fontSize: 15, height: 1.4, color: _muted)),
          const SizedBox(height: 24),
          for (final o in q.opts) ...[
            _OptionTile(opt: o, selected: selected == o.value, onTap: () => onPick(o.value)),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final _Opt opt;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.opt, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: opt.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? _orangeSoft : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? _orange : _line, width: selected ? 2 : 1.5),
            ),
            child: Row(children: [
              Icon(opt.icon, color: selected ? _orange : _ink, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Text(opt.label,
                    style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w500, color: _ink)),
              ),
              if (selected) const Icon(Icons.check_circle_rounded, color: _orange),
            ]),
          ),
        ),
      ),
    );
  }
}
