import 'package:flutter/material.dart';

import '../theme/prefs.dart';
import 'diary.dart';
import 'profile.dart';
import 'today.dart';

/// The app once a program is running: Home, Saves and Profile tabs.
class AppShell extends StatefulWidget {
  final String pledgeId;
  const AppShell({super.key, required this.pledgeId});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        TodayScreen(pledgeId: widget.pledgeId),
        const DiaryScreen(),
        const ProfileScreen(),
      ]),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: p.card,
          indicatorColor: p.sunSoft,
          labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink)),
          iconTheme: WidgetStatePropertyAll(IconThemeData(color: p.ink)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.bookmark_border_rounded), selectedIcon: Icon(Icons.bookmark_rounded), label: 'Saves'),
            NavigationDestination(
                icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
