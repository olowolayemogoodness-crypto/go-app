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
const int _maxHabits = 5;

/// After sign-in: questionnaire once, then one setup page per chosen habit, then Home.
/// Only server-confirmed data drives the flow, so a refused save can never skip a step.
class PostAuthGate extends StatefulWidget {
  const PostAuthGate({super.key});
  @override
  State<PostAuthGate> createState() => _PostAuthGateState();
}

bool _isConfigured(Map h) => h['configured'] == true || ((h['config'] as Map?)?.isNotEmpty ?? false);

class _PostAuthGateState extends State<PostAuthGate> {
  Map<String, dynamic>? _data;
  bool _got = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(backgroundColor: _bg);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.doc('users/$uid').snapshots(includeMetadataChanges: true),
      builder: (context, snap) {
        if (snap.hasError) return const HomeGate(); // never trap the user on a blank screen
        final ds = snap.data;
        if (ds != null && !ds.metadata.hasPendingWrites && !(ds.metadata.isFromCache && !ds.exists)) {
          _data = ds.data();
          _got = true;
        }
        if (!_got) return const Scaffold(backgroundColor: _bg);
        final d = _data;
        if (d == null || d['onboarded'] != true) return const OnboardingScreen(key: ValueKey('onboarding'));
        final habits = [
          for (final h in (((d['profile'] as Map?)?['habits'] as List?) ?? const [])) Map<String, dynamic>.from(h as Map)
        ];
        final i = habits.indexWhere((h) => !_isConfigured(h));
        if (i >= 0) {
          return HabitSetupScreen(key: ValueKey('setup-${habits[i]['id']}'), habits: habits, index: i);
        }
        return const HomeGate();
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
  final bool text; // free text instead of choices
  const _Q(this.id, this.title, this.sub, this.opts, {this.text = false});
}

const _general = <_Q>[
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
];

_Q _minutes(String title, List<int> mins) => _Q('amount', title, 'You can change this later in your profile.', [
      for (final m in mins) _Opt('$m', '$m minutes', Icons.timer_outlined),
    ]);

class _Habit {
  final String id, kind, blurb;
  final IconData icon;
  final List<_Q> qs;
  final String Function(Map<String, String> a) titleFor;
  const _Habit(this.id, this.kind, this.icon, this.blurb, this.qs, this.titleFor);
}

final _habits = <_Habit>[
  _Habit('github', 'github', Icons.code_rounded, 'Proved by your public GitHub activity', const [
    _Q('user', 'What is your GitHub username?', 'We read your public commits to check this habit off.', [], text: true),
  ], (_) => 'Push a commit'),
  _Habit('screen', 'camera', Icons.phone_iphone_rounded, 'Earns an XP boost', const [
    _Q('limit', 'What is your daily screen-time limit?', 'Stay under it and your XP gets a boost.', [
      _Opt('2', 'Under 2 hours', Icons.phone_iphone_rounded),
      _Opt('3', 'Under 3 hours', Icons.phone_iphone_rounded),
      _Opt('4', 'Under 4 hours', Icons.phone_iphone_rounded),
      _Opt('5', 'Under 5 hours', Icons.phone_iphone_rounded),
    ]),
  ], (a) => 'Screen time under ${a['limit'] ?? '3'} hours'),
  _Habit('workout', 'camera', Icons.fitness_center_rounded, 'Show it on camera', [
    _minutes('How long is your workout?', [10, 20, 30, 45]),
  ], (a) => 'Workout ${a['amount'] ?? '20'} minutes'),
  _Habit('study', 'camera', Icons.menu_book_outlined, 'Show it on camera', [
    _minutes('How long do you want to study?', [20, 30, 60, 90]),
  ], (a) => 'Study ${a['amount'] ?? '30'} minutes'),
  _Habit('read', 'camera', Icons.auto_stories_outlined, 'Show it on camera', const [
    _Q('pages', 'How many pages a day?', 'You can change this later in your profile.', [
      _Opt('10', '10 pages', Icons.auto_stories_outlined),
      _Opt('20', '20 pages', Icons.auto_stories_outlined),
      _Opt('30', '30 pages', Icons.auto_stories_outlined),
      _Opt('50', '50 pages', Icons.auto_stories_outlined),
    ]),
  ], (a) => 'Read ${a['pages'] ?? '20'} pages'),
  _Habit('sleep', 'camera', Icons.bedtime_outlined, 'Show it on camera', const [
    _Q('time', 'What time should your phone go down?', 'Pick a bedtime you can really keep.', [
      _Opt('10pm', '10pm', Icons.bedtime_outlined),
      _Opt('11pm', '11pm', Icons.bedtime_outlined),
      _Opt('midnight', 'Midnight', Icons.bedtime_outlined),
    ]),
  ], (a) => 'Phone down by ${a['time'] ?? '11pm'}'),
  _Habit('money', 'camera', Icons.savings_outlined, 'Show it on camera', const [
    _Q('where', 'Where do you track your spending?', 'You will show it on camera each day.', [
      _Opt('notes', 'In a notes app', Icons.edit_note_rounded),
      _Opt('bank', 'In my bank app', Icons.account_balance_outlined),
      _Opt('sheet', 'In a spreadsheet', Icons.table_chart_outlined),
    ]),
  ], (_) => "Log today's spending"),
  _Habit('tidy', 'camera', Icons.checklist_rounded, 'Show it on camera', [
    _minutes('How long do you want to tidy?', [5, 10, 20]),
  ], (a) => 'Tidy desk for ${a['amount'] ?? '10'} minutes'),
];


const _general_ = _general;

Widget _h1(String t) => Semantics(
      header: true,
      child: Text(t, style: GoogleFonts.fredoka(fontSize: 32, height: 1.1, fontWeight: FontWeight.w700, color: _ink)),
    );

Widget _bigButton(String label, VoidCallback? onTap) => SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          disabledBackgroundColor: _line,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label, style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );

/// General questions (one per screen), then one screen to tick the habits.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0.._general.length-1 questions, then the habit list
  bool _forward = true;
  bool _saving = false;
  final Map<String, String> _answers = {};
  final Set<String> _picked = {};

  bool get _onList => _step >= _general_.length;

  Future<void> _answer(String v) async {
    setState(() => _answers[_general_[_step].id] = v);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      _forward = true;
      _step++;
    });
  }

  void _back() {
    if (_step == 0 || _saving) return;
    setState(() {
      _forward = false;
      _step--;
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
      } else if (_picked.length < _maxHabits) {
        _picked.add(id);
      }
    });
  }

  Future<void> _finish() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _picked.isEmpty) return;
    setState(() => _saving = true);
    final habits = [
      for (final h in _habits)
        if (_picked.contains(h.id)) {'id': h.id, 'title': h.titleFor(const {}), 'kind': h.kind, 'config': {}, 'configured': false}
    ];
    try {
      await FirebaseFirestore.instance.doc('users/$uid').set({
        'onboarded': true,
        'xp': 0,
        'profile': {
          ..._answers,
          'githubUser': '',
          'habits': habits,
          'suggested': [for (final h in habits) {'title': h['title'], 'kind': h['kind']}],
          'completedAtMs': DateTime.now().millisecondsSinceEpoch,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSaveError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = prefs.reduceMotionFor(context);
    final progress = (_step + 1) / (_general_.length + 2);
    final Widget page = _onList
        ? _PickListView(
            key: const ValueKey('list'),
            picked: _picked,
            onToggle: _toggle,
            onContinue: _picked.isEmpty ? null : _finish,
          )
        : _ChoiceView(
            key: ValueKey(_step),
            q: _general_[_step],
            selected: _answers[_general_[_step].id],
            onPick: _answer,
          );
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
                    Expanded(child: _ProgressBar(value: progress, reduce: reduce)),
                    const SizedBox(width: 48),
                  ]),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _saving
                        ? Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const CircularProgressIndicator(color: _orange),
                              const SizedBox(height: 16),
                              Text('Saving...', style: GoogleFonts.lexend(fontSize: 16, color: _muted)),
                            ]),
                          )
                        : AnimatedSwitcher(
                            duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
                            transitionBuilder: (child, anim) {
                              final incoming = child.key == (_onList ? const ValueKey('list') : ValueKey(_step));
                              final dx = (incoming ? 1.0 : -1.0) * (_forward ? 1 : -1) * 0.12;
                              return FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim),
                                  child: child,
                                ),
                              );
                            },
                            child: page,
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

void _showSaveError(BuildContext context, Object e) {
  final code = e is FirebaseException ? e.code : e.runtimeType.toString();
  final hint = code == 'permission-denied'
      ? 'Firestore refused it. Deploy the rules: firebase deploy --only firestore:rules'
      : (code == 'not-found' || code == 'failed-precondition')
          ? 'The Firestore database may not exist yet. Create it in the Firebase console.'
          : 'Check your connection and try again.';
  debugPrint('Save failed: $e');
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(duration: const Duration(seconds: 8), content: Text('Could not save ($code). $hint')));
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final bool reduce;
  const _ProgressBar({required this.value, required this.reduce});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => LinearProgressIndicator(
            value: v,
            minHeight: 8,
            backgroundColor: _line,
            valueColor: const AlwaysStoppedAnimation(_orange),
          ),
        ),
      );
}

class _ChoiceView extends StatelessWidget {
  final _Q q;
  final String? selected;
  final ValueChanged<String> onPick;
  const _ChoiceView({super.key, required this.q, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _h1(q.title),
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

/// One screen: tick every habit you want (up to 5), then Continue.
class _PickListView extends StatelessWidget {
  final Set<String> picked;
  final ValueChanged<String> onToggle;
  final VoidCallback? onContinue;
  const _PickListView({super.key, required this.picked, required this.onToggle, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _h1('Pick your habits'),
        const SizedBox(height: 8),
        Text('Choose up to $_maxHabits. You will set each one up next. ${picked.length} of $_maxHabits chosen.',
            style: GoogleFonts.lexend(fontSize: 15, height: 1.4, color: _muted)),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(children: [
            for (final h in _habits) ...[
              _HabitTile(
                h: h,
                selected: picked.contains(h.id),
                onTap: () => onToggle(h.id),
              ),
              const SizedBox(height: 10),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        _bigButton(picked.isEmpty ? 'Pick at least one' : 'Continue', onContinue),
      ],
    );
  }
}

class _HabitTile extends StatelessWidget {
  final _Habit h;
  final bool selected;
  final VoidCallback onTap;
  const _HabitTile({required this.h, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final boost = h.blurb.contains('XP');
    final title = h.titleFor(const {});
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. ${h.blurb}',
      excludeSemantics: true,
      child: Material(
        color: selected ? _orangeSoft : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? _orange : _line, width: selected ? 2 : 1.5),
            ),
            child: Row(children: [
              Icon(h.icon, color: (selected || boost) ? _orange : _ink, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w500, color: _ink)),
                  Text(h.blurb,
                      style: GoogleFonts.lexend(
                          fontSize: 12, color: boost ? _orange : _muted, fontWeight: boost ? FontWeight.w600 : FontWeight.w400)),
                ]),
              ),
              Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? _orange : _line),
            ]),
          ),
        ),
      ),
    );
  }
}

/// One page per habit: all of its questions at once, so users reach their goal.
class HabitSetupScreen extends StatefulWidget {
  final List<Map<String, dynamic>> habits;
  final int index;
  const HabitSetupScreen({super.key, required this.habits, required this.index});
  @override
  State<HabitSetupScreen> createState() => _HabitSetupScreenState();
}

class _HabitSetupScreenState extends State<HabitSetupScreen> {
  late final _Habit _habit = _habits.firstWhere((h) => h.id == widget.habits[widget.index]['id']);
  final Map<String, String> _cfg = {};
  final _text = TextEditingController();
  String? _err;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _complete => _habit.qs.every((q) => q.text ? _text.text.trim().isNotEmpty : _cfg.containsKey(q.id));

  Future<void> _save() async {
    for (final q in _habit.qs.where((q) => q.text)) {
      final v = _text.text.trim().replaceFirst(RegExp(r'^@'), '');
      if (!RegExp(r'^[a-zA-Z0-9-]{1,39}$').hasMatch(v)) {
        setState(() => _err = 'Use letters, numbers and dashes only, like octocat.');
        return;
      }
      _cfg[q.id] = v;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    final list = [for (final h in widget.habits) Map<String, dynamic>.from(h)];
    list[widget.index] = {
      ...list[widget.index],
      'title': _habit.titleFor(_cfg),
      'config': Map<String, String>.from(_cfg),
      'configured': true,
    };
    final gh = [for (final h in list) if (h['id'] == 'github') (h['config'] as Map)['user'] ?? ''].firstOrNull ?? '';
    try {
      await FirebaseFirestore.instance.doc('users/$uid').update({
        'profile.habits': list,
        'profile.suggested': [for (final h in list) {'title': h['title'], 'kind': h['kind']}],
        'profile.githubUser': gh,
      });
      // PostAuthGate moves to the next habit (or Home) once the server confirms.
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSaveError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.habits.length;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Kicker('Habit ${widget.index + 1} of $total'),
                  _h1(_habit.titleFor(_cfg)),
                  const SizedBox(height: 8),
                  Text('A few quick answers so GO can help you reach this goal.',
                      style: GoogleFonts.lexend(fontSize: 15, height: 1.4, color: _muted)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (final q in _habit.qs) ...[
                          Text(q.title, style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
                          const SizedBox(height: 4),
                          Text(q.sub, style: GoogleFonts.lexend(fontSize: 13, color: _muted)),
                          const SizedBox(height: 12),
                          if (q.text)
                            TextField(
                              controller: _text,
                              autocorrect: false,
                              onChanged: (_) => setState(() => _err = null),
                              style: GoogleFonts.lexend(fontSize: 17),
                              decoration: InputDecoration(
                                hintText: 'octocat',
                                errorText: _err,
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(Icons.alternate_email_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _line, width: 1.5)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _line, width: 1.5)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _orange, width: 2)),
                              ),
                            )
                          else
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final o in q.opts)
                                ChoiceChip(
                                  label: Text(o.label, style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w500)),
                                  selected: _cfg[q.id] == o.value,
                                  showCheckmark: false,
                                  selectedColor: _orangeSoft,
                                  backgroundColor: Colors.white,
                                  side: BorderSide(color: _cfg[q.id] == o.value ? _orange : _line, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  onSelected: (_) => setState(() => _cfg[q.id] = o.value),
                                ),
                            ]),
                          const SizedBox(height: 24),
                        ],
                      ]),
                    ),
                  ),
                  _saving
                      ? const Center(child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(color: _orange)))
                      : _bigButton(widget.index + 1 == total ? 'Finish' : 'Next habit', _complete ? _save : null),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Kicker extends StatelessWidget {
  final String text;
  const _Kicker(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: _orangeSoft, borderRadius: BorderRadius.circular(99)),
            child: Text(text, style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600, color: _orange)),
          ),
        ),
      );
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
