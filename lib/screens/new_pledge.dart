import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api.dart';
import '../widgets/habit_cards.dart';

const _bg = Color(0xFFFFF9F2);
const _ink = Color(0xFF1B1B1F);
const _muted = Color(0xFF6C6C75);
const _orange = Color(0xFFE08813);
const _soft = Color(0xFFFFF0DA);
const _line = Color(0xFFE9DFD2);

/// Your plan: the habits you chose, a simulated premium, a partner, start.
class NewPledgeScreen extends StatefulWidget {
  const NewPledgeScreen({super.key});
  @override
  State<NewPledgeScreen> createState() => _NewPledgeScreenState();
}

class _NewPledgeScreenState extends State<NewPledgeScreen> {
  List<Map<String, String>> _habits = [];
  String _github = '';
  int _premium = 1000;
  final _partner = TextEditingController();
  bool _loading = true, _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _partner.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final s = await FirebaseFirestore.instance.doc('users/$uid').get();
      final prof = (s.data()?['profile'] as Map?) ?? {};
      _github = '${prof['githubUser'] ?? ''}';
      _habits = [
        for (final h in (prof['habits'] as List? ?? const []))
          {'title': '${(h as Map)['title']}', 'kind': '${h['kind']}' == 'github' ? 'github' : 'camera'}
      ];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _start() async {
    if (_habits.isEmpty) return setState(() => _err = 'No habits found. Sign out and pick your habits again.');
    if (_partner.text.trim().isEmpty) return setState(() => _err = 'Name your accountability partner.');
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await Api.createPledge({
        'activities': _habits,
        'premium': _premium,
        'partnerName': _partner.text.trim(),
        'githubUser': _habits.any((h) => h['kind'] == 'github') ? _github : '',
        'tzOffsetMin': DateTime.now().timeZoneOffset.inMinutes,
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.message);
    } catch (e) {
      if (mounted) setState(() => _err = 'Could not start: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 22),
        child: Text(t, style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _orange))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 28), children: [
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
                    Text('Your 30-day plan',
                        style: GoogleFonts.fredoka(fontSize: 32, fontWeight: FontWeight.w700, color: _ink, height: 1.1)),
                    const SizedBox(height: 8),
                    Text(
                        'Finish at least one habit every day (3 grace passes) and 90% overall, and you get your whole fee back.',
                        style: GoogleFonts.lexend(fontSize: 14, height: 1.45, color: _muted)),
                    _label('Your habits'),
                    for (final h in _habits)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line, width: 1.5)),
                        child: Row(children: [
                          Icon(h['kind'] == 'github' ? Icons.code_rounded : _iconFor(h['title']!), color: _orange),
                          const SizedBox(width: 12),
                          Expanded(child: Text(h['title']!, style: GoogleFonts.lexend(fontSize: 15, color: _ink))),
                        ]),
                      ),
                    _label('Commitment fee: $_premium coins'),
                    Wrap(spacing: 8, children: [
                      for (final v in const [500, 1000, 2000, 3000])
                        ChoiceChip(
                          label: Text('$v', style: GoogleFonts.lexend(fontWeight: FontWeight.w600)),
                          selected: _premium == v,
                          showCheckmark: false,
                          selectedColor: _soft,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: _premium == v ? _orange : _line, width: 1.5),
                          onSelected: (_) => setState(() => _premium = v),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Text('Follow through and all $_premium comes back. Quit and GO keeps it.',
                        style: GoogleFonts.lexend(fontSize: 13, color: _muted)),
                    _label('Accountability partner'),
                    TextField(
                      controller: _partner,
                      style: GoogleFonts.lexend(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Who can overrule the checker?',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line, width: 1.5)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line, width: 1.5)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _orange, width: 2)),
                      ),
                    ),
                    if (_err != null) ...[
                      const SizedBox(height: 12),
                      Text(_err!, style: GoogleFonts.lexend(fontSize: 13, color: const Color(0xFFC0392B))),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _busy ? null : _start,
                        style: FilledButton.styleFrom(
                            backgroundColor: _ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                        child: Text(_busy ? 'Starting...' : 'Commit $_premium and start',
                            style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
              ),
      ),
    );
  }

  IconData _iconFor(String title) {
    switch (habitTypeOf(title)) {
      case HabitType.screen:
        return Icons.phone_iphone_rounded;
      case HabitType.workout:
        return Icons.fitness_center_rounded;
      case HabitType.study:
        return Icons.menu_book_outlined;
      case HabitType.read:
        return Icons.auto_stories_outlined;
      case HabitType.sleep:
        return Icons.bedtime_outlined;
      case HabitType.money:
        return Icons.savings_outlined;
      case HabitType.tidy:
        return Icons.checklist_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }
}
