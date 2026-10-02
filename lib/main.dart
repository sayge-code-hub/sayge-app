import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_session.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sayge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
