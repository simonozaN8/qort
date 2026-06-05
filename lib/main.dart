import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/qort_theme.dart';
import 'core/theme/qort_theme_notifier.dart';
import 'core/theme/qort_typography.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env neprivalomas — galima naudoti --dart-define
  }

  await QortTypography.preload();
  await initializeDateFormatting('lt_LT', null);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  runApp(const QortApp());
}

class QortApp extends StatefulWidget {
  const QortApp({super.key});

  @override
  State<QortApp> createState() => _QortAppState();
}

class _QortAppState extends State<QortApp> {
  Session? _session;
  bool _isLoading = true;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    QortThemeNotifier.instance.load();
    QortThemeNotifier.instance.addListener(_onThemeChanged);
    _initSession();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (mounted &&
          (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.signedOut)) {
        setState(() {
          _session = session;
        });
      }
    });
  }

  @override
  void dispose() {
    QortThemeNotifier.instance.removeListener(_onThemeChanged);
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = QortThemeNotifier.instance.palette;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            palette.isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'QORT',
      debugShowCheckedModeBanner: false,
      locale: const Locale('lt', 'LT'),
      supportedLocales: const [Locale('en', 'US'), Locale('lt', 'LT')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: QortTheme.fromPalette(palette),
      home: _isLoading
          ? Scaffold(backgroundColor: palette.background)
          : (_session != null ? const AuthGate() : const LoginScreen()),
    );
  }
}
