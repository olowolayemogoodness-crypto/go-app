import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth.dart';
import '../theme/prefs.dart';
import 'onboarding.dart';

/// The logo's own background colour: the whole welcome screen is this orange.
const Color kGoOrange = Color(0xFFE08813);
const Color _ink = Color(0xFF14110F);

// Logo geometry (original image is 1024 x 1024). The runner's foot and the
// bottom of the speed lines sit at about y = 805.
const double _kFootY = 805 / 1024;

/// Shows the app when someone is signed in, otherwise the welcome page.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: kGoOrange);
        }
        final u = snap.data;
        return ValueListenableBuilder<bool>(
          valueListenable: AuthService.guest,
          builder: (context, guest, _) {
            if (u != null && (!u.isAnonymous || guest)) return const PostAuthGate();
            return const WelcomeScreen();
          },
        );
      },
    );
  }
}

double _seg(double t, double a, double b, [Curve c = Curves.linear]) {
  if (t <= a) return 0;
  if (t >= b) return 1;
  return c.transform((t - a) / (b - a));
}

/// Splash + sign-in in one screen: the logo appears, "Connect to GitHub" rises
/// from the bottom and trips over the runner's foot, then "Connect to Google" follows.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
  bool _started = false;
  String? _busy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = prefs.reduceMotionFor(context);
    precacheImage(const AssetImage('assets/images/go_logo.png'), context).then((_) {
      if (!mounted) return;
      if (reduce) {
        _c.value = 1;
      } else {
        _c.forward();
      }
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

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width, h = mq.size.height;
    const btnH = 58.0, gap = 12.0, footer = 96.0;
    final btnW = math.min(w - 48, 440.0);
    final left = (w - btnW) / 2;

    // Logo as large as fits: leave room for two buttons and the footer below it.
    final top = mq.padding.top + 16;
    final room = h - top - mq.padding.bottom - footer - btnH * 2 - gap - 24;
    final s = math.max(200.0, math.min(math.min(w * 0.94, 520.0), room / _kFootY));
    final logoLeft = (w - s) / 2;
    final ghTop = top + s * _kFootY + 2;
    final gTop = ghTop + btnH + gap;

    return Scaffold(
      backgroundColor: kGoOrange,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;

          // Logo eases in.
          final lp = _seg(t, 0.0, 0.14, Curves.easeOutBack);
          final lo = _seg(t, 0.0, 0.08);

          // GitHub: accelerates upward, hits the foot, stumbles and wobbles to rest.
          final rise = _seg(t, 0.16, 0.36, Curves.easeInQuad);
          final ghY = (h - ghTop + 20) * (1 - rise);
          final u = _seg(t, 0.36, 0.64);
          final hit = t >= 0.36;
          final wobble = hit ? -0.15 * math.exp(-4.5 * u) * math.cos(u * 15) : 0.0;
          final hop = hit ? -16 * math.exp(-6 * u) * math.sin(u * 18).abs() : 0.0;

          // Google: follows with a little overshoot.
          final g = _seg(t, 0.50, 0.74, Curves.easeOutBack);
          final gY = (h - gTop + 20) * (1 - g);

          final tail = _seg(t, 0.76, 0.92);
          final ghReady = t >= 0.64;
          final gReady = t >= 0.74;

          return Stack(children: [
            Positioned(
              left: logoLeft,
              top: top,
              width: s,
              height: s,
              child: Opacity(
                opacity: lo,
                child: Transform.scale(
                  scale: 0.88 + 0.12 * lp.clamp(0.0, 1.2),
                  child: Semantics(
                    label: 'GO',
                    image: true,
                    child: Image.asset('assets/images/go_logo.png', fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            if (t >= 0.16)
              Positioned(
                left: left,
                top: ghTop,
                width: btnW,
                height: btnH,
                child: Transform.translate(
                  offset: Offset(0, ghY + hop),
                  child: Transform.rotate(
                    angle: wobble,
                    alignment: Alignment.topLeft,
                    child: _Btn(
                      label: 'Connect to GitHub',
                      icon: Icons.code_rounded,
                      dark: true,
                      loading: _busy == 'gh',
                      onTap: (!ghReady || _busy != null)
                          ? null
                          : () => _run('gh', AuthService.signInWithGitHub),
                    ),
                  ),
                ),
              ),
            if (t >= 0.50)
              Positioned(
                left: left,
                top: gTop,
                width: btnW,
                height: btnH,
                child: Transform.translate(
                  offset: Offset(0, gY),
                  child: _Btn(
                    label: 'Connect to Google',
                    icon: Icons.account_circle_outlined,
                    loading: _busy == 'g',
                    onTap: (!gReady || _busy != null)
                        ? null
                        : () => _run('g', AuthService.signInWithGoogle),
                  ),
                ),
              ),
            Positioned(
              left: 24,
              right: 24,
              bottom: mq.padding.bottom + 12,
              child: Opacity(
                opacity: tail,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(
                    onPressed: (_busy != null || tail < 1)
                        ? null
                        : () => _run('guest', AuthService.continueAsGuest),
                    style: TextButton.styleFrom(foregroundColor: _ink, minimumSize: const Size(0, 48)),
                    child: Text('Try it without an account',
                        style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  Text(
                    'Demo app. All money in GO is simulated.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(fontSize: 12, color: _ink.withValues(alpha: 0.7)),
                  ),
                ]),
              ),
            ),
          ]);
        },
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
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: dark ? Colors.white : kGoOrange),
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
