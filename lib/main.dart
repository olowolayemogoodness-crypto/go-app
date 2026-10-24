import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'screens/home.dart';
import 'screens/partner.dart';
import 'screens/sign_in.dart';
import 'theme/prefs.dart';

/// If the app was opened on /confirm/{token}, return the token.
String? _partnerTokenFromUrl() {
  final u = Uri.base;
  var segs = u.pathSegments;
  if (segs.length >= 2 && segs[0] == 'confirm') return segs[1];
  // Hash-routing fallback: /#/confirm/{token}
  final frag = u.fragment;
  if (frag.isNotEmpty) {
    segs = Uri.parse(frag).pathSegments;
    if (segs.length >= 2 && segs[0] == 'confirm') return segs[1];
  }
  return null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await prefs.load();
  final token = _partnerTokenFromUrl();
  if (token != null && FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  runApp(PledgeApp(partnerToken: token));
}

class PledgeApp extends StatelessWidget {
  final String? partnerToken;
  const PledgeApp({super.key, this.partnerToken});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        return MaterialApp(
          title: 'GO',
          debugShowCheckedModeBanner: false,
          builder: (ctx, child) {
            // Theme depends on MediaQuery (OS contrast / motion), so build it here.
            final mq = MediaQuery.of(ctx);
            final scale = prefs.largeText ? 1.4 : 1.0;
            return Theme(
              data: buildTheme(ctx),
              child: MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(
                      (mq.textScaler.scale(1.0) * scale).clamp(1.0, 2.0)),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: partnerToken != null
              ? PartnerScreen(token: partnerToken!)
              : const AuthGate(),
        );
      },
    );
  }
}
