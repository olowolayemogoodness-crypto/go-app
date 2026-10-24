import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth.dart';
import '../theme/prefs.dart';
import 'home.dart';

const Color _bg = Color(0xFFFFF9F2);
const Color _ink = Color(0xFF1B1B1F);
const Color _muted = Color(0xFF6C6C75);
const Color _orange = Color(0xFFE08813);

/// Shows the app when someone is signed in, otherwise the sign-in page.
class AuthGate extends StatelessWidget {
  /// Wait this long before the sign-in page animates in (the intro is still playing).
  final Duration entranceDelay;
  const AuthGate({super.key, this.entranceDelay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: _bg);
        }
        final u = snap.data;
        return ValueListenableBuilder<bool>(
          valueListenable: AuthService.guest,
          builder: (context, guest, _) {
            if (u != null && (!u.isAnonymous || guest)) return const HomeGate();
            return SignInScreen(entranceDelay: entranceDelay);
          },
        );
      },
    );
  }
}

class SignInScreen extends StatefulWidget {
  final Duration entranceDelay;
  const SignInScreen({super.key, this.entranceDelay = Duration.zero});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  String? _busy;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.entranceDelay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _run(String which, Future<void> Function() f) async {
    setState(() => _busy = which);
    try {
      await f();
    } on AuthError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Staggered fade + rise, item [i] of the page.
  Widget _in(int i, Widget child) {
    final reduce = prefs.reduceMotionFor(context);
    if (reduce) return child;
    final a = (i * 0.11).clamp(0.0, 0.7);
    final anim = CurvedAnimation(parent: _c, curve: Interval(a, (a + 0.45).clamp(0.0, 1.0), curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: anim,
      builder: (_, w) => Opacity(
        opacity: anim.value,
        child: Transform.translate(offset: Offset(0, 24 * (1 - anim.value)), child: w),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final head = GoogleFonts.fredoka(fontSize: 42, height: 1.05, fontWeight: FontWeight.w700, color: _ink);
    final body = GoogleFonts.lexend(fontSize: 16, height: 1.5, color: _muted);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _in(
                    0,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset('assets/images/go_logo.png', width: 60, height: 60),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _in(1, Text('Stop dodging\nyour own\ndeadlines.', style: head)),
                  const SizedBox(height: 16),
                  _in(
                    2,
                    Text(
                      'Pick your daily habits, keep a 30-day streak and prove it. '
                      'Built for developers whose life runs on commits, not calendars.',
                      style: body,
                    ),
                  ),
                  const Spacer(),
                  _in(
                    3,
                    _Btn(
                      label: 'Continue with GitHub',
                      icon: Icons.code_rounded,
                      dark: true,
                      loading: _busy == 'gh',
                      onTap: _busy != null ? null : () => _run('gh', AuthService.signInWithGitHub),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _in(
                    4,
                    _Btn(
                      label: 'Continue with Google',
                      icon: Icons.account_circle_outlined,
                      loading: _busy == 'g',
                      onTap: _busy != null ? null : () => _run('g', AuthService.signInWithGoogle),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _in(
                    5,
                    TextButton(
                      onPressed: _busy != null ? null : () => _run('guest', AuthService.continueAsGuest),
                      style: TextButton.styleFrom(foregroundColor: _muted, minimumSize: const Size(0, 48)),
                      child: Text('Try it without an account', style: GoogleFonts.lexend(fontSize: 14)),
                    ),
                  ),
                  _in(
                    6,
                    Text(
                      'Demo app. All money in GO is simulated.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexend(fontSize: 12, color: _muted),
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

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool dark;
  final bool loading;
  final VoidCallback? onTap;
  const _Btn({required this.label, required this.icon, this.dark = false, this.loading = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : _ink;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: dark ? _ink : Colors.white,
        elevation: dark ? 0 : 0,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: dark ? null : Border.all(color: const Color(0xFFE4DCD2), width: 1.5),
            ),
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: dark ? Colors.white : _orange),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: fg, size: 22),
                    const SizedBox(width: 10),
                    Text(label, style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600, color: fg)),
                  ]),
          ),
        ),
      ),
    );
  }
}
