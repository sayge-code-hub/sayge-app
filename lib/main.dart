import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/auth_session.dart';
import 'core/auth/password_setup.dart';
import 'core/router/app_router.dart';
import 'core/router/url_strategy.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Path URLs keep /set-password as the route; Supabase invite tokens stay in
  // the hash (#…) and must not be parsed as go_router locations (e.g. /sb).
  configureAppUrlStrategy();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await initDependencies();

  runApp(SaygeApp(authSession: sl<AuthSession>()));
}

class SaygeApp extends StatefulWidget {
  const SaygeApp({super.key, required this.authSession});

  final AuthSession authSession;

  @override
  State<SaygeApp> createState() => _SaygeAppState();
}

class _SaygeAppState extends State<SaygeApp> {
  late final GoRouter _router = createAppRouter(widget.authSession);

  @override
  void initState() {
    super.initState();
    // Invite links hydrate the session after startup — keep password gate on.
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session == null) return;
      if (PasswordSetup.currentUserRequiresSetup()) {
        widget.authSession.requirePasswordSetup();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sayge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
