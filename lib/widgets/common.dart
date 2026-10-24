import 'package:flutter/material.dart';
import '../theme/prefs.dart';

/// Persistent honesty badge. Shown on every screen.
class SimBadge extends StatelessWidget {
  const SimBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Semantics(
      label: 'Simulated premium. No real money is used.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('SIMULATED PREMIUM · no real money',
            style: TextStyle(color: p.ground, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}

/// Standard page scaffold: centred column, max width, badge on top.
class PageShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showBack;
  final bool showBadge;
  const PageShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showBack = true,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: showBack,
        actions: [
          ...?actions,
          IconButton(
            tooltip: 'Accessibility settings',
            icon: const Icon(Icons.accessibility_new),
            onPressed: () => showAccessibilitySheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBadge) ...[
                    const Align(alignment: Alignment.centerLeft, child: SimBadge()),
                    const SizedBox(height: 16),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card with a thick outline and a hard offset shadow.
class ChunkyCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final double angle;
  final bool shadow;
  const ChunkyCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(18),
    this.angle = 0,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget w = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.ink, width: 2.5),
        boxShadow: shadow ? [BoxShadow(color: p.ink, offset: const Offset(0, 6))] : null,
      ),
      child: child,
    );
    if (angle != 0) w = Transform.rotate(angle: angle, child: w);
    return Padding(padding: EdgeInsets.only(bottom: shadow ? 6 : 0), child: w);
  }
}

/// Big tomato button with a hard bottom shadow.
class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  const BigButton({super.key, required this.label, required this.onPressed, this.icon, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final enabled = onPressed != null;
    final r = BorderRadius.circular(18);
    final fg = outlined ? p.primary : (enabled ? p.onPrimary : p.muted);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Container(
        margin: EdgeInsets.only(bottom: outlined ? 0 : 5),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : (enabled ? p.primary : p.line),
          borderRadius: r,
          border: outlined ? Border.all(color: p.primary, width: 2) : null,
          boxShadow: (!outlined && enabled)
              ? [BoxShadow(color: p.primaryShadow, offset: const Offset(0, 5))]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: r,
            onTap: onPressed,
            child: SizedBox(
              height: outlined ? 54 : 58,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, color: fg, size: 22), const SizedBox(width: 10)],
                    Flexible(
                      child: Text(label,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: fg),
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The big battery: one segment per activity, filled as activities are done.
class BatteryMeter extends StatelessWidget {
  final int done;
  final int total;
  const BatteryMeter({super.key, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final reduce = prefs.reduceMotionFor(context);
    final pct = total == 0 ? 0 : (100 * done / total).round();
    final next = done < total ? done : -1;
    return Semantics(
      label: 'Battery $pct percent charged. $done of $total activities done today.',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 112,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: p.ground,
                  border: Border.all(color: p.ink, width: 5),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < total; i++) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Expanded(
                        child: AnimatedContainer(
                          duration: reduce ? Duration.zero : const Duration(milliseconds: 500),
                          curve: Curves.easeOutBack,
                          decoration: BoxDecoration(
                            color: i < done ? p.orange : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: i < done ? null : Border.all(color: p.field, width: 2.5),
                          ),
                          child: i == next
                              ? Center(child: Icon(Icons.bolt, size: 28, color: p.primary))
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              width: 12,
              height: 42,
              decoration: BoxDecoration(
                color: p.ink,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color textColor;
  const StatTile({super.key, required this.value, required this.label, required this.color, required this.textColor});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.ink, width: 2),
      ),
      child: Column(
        children: [
          Text(value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: textColor)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }
}

class AccessibilityToggles extends StatelessWidget {
  const AccessibilityToggles({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Large text'),
            value: prefs.largeText,
            onChanged: prefs.setLargeText,
          ),
          SwitchListTile(
            title: const Text('High contrast'),
            value: prefs.highContrastFor(context),
            onChanged: prefs.setHighContrast,
          ),
          SwitchListTile(
            title: const Text('Dyslexia-friendly font'),
            value: prefs.dyslexiaFont,
            onChanged: prefs.setDyslexia,
          ),
          SwitchListTile(
            title: const Text('Reduce motion'),
            value: prefs.reduceMotionFor(context),
            onChanged: prefs.setReduceMotion,
          ),
        ],
      ),
    );
  }
}

void showAccessibilitySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const SafeArea(
      child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: AccessibilityToggles()),
    ),
  );
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
