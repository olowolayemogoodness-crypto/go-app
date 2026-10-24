import 'package:flutter/material.dart';

import '../theme/prefs.dart';

/// The logo's own background colour, so the image melts into the screen edges.
const Color kGoOrange = Color(0xFFE08813);

/// Splash: the supplied GO logo, shown as-is. It eases in, holds, then dashes
/// off to the right while the next screen fades in.
class SplashScreen extends StatefulWidget {
  final WidgetBuilder next;
  const SplashScreen({super.key, required this.next});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  bool _started = false;
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduce = prefs.reduceMotionFor(context);
    precacheImage(const AssetImage('assets/images/go_logo.png'), context).then((_) => _run());
  }

  Future<void> _run() async {
    if (!mounted) return;
    if (_reduce) {
      _c.value = 0.4;
      await Future.delayed(const Duration(milliseconds: 900));
    } else {
      await _c.forward();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: _reduce ? Duration.zero : const Duration(milliseconds: 450),
      pageBuilder: (ctx, _, __) => widget.next(ctx),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final intro = CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.25, curve: Curves.easeOutBack));
    final exit = CurvedAnimation(parent: _c, curve: const Interval(0.72, 1.0, curve: Curves.easeInCubic));
    return Scaffold(
      backgroundColor: kGoOrange,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final inV = intro.value.clamp(0.0, 1.2);
          final outV = exit.value;
          final opacity = (_c.value < 0.25 ? (_c.value / 0.25) : 1.0) * (1 - outV);
          final scale = (0.86 + 0.14 * inV) * (1 + 0.12 * outV);
          return Center(
            child: Transform.translate(
              offset: Offset(w * 0.45 * outV, 0),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Semantics(
                    label: 'GO',
                    image: true,
                    child: Image.asset(
                      'assets/images/go_logo.png',
                      width: (w * 0.9).clamp(240.0, 560.0),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
