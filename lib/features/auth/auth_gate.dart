import 'package:flutter/material.dart';
import '../../core/theme/qort_palette_extension.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main_wrapper.dart';
import '../onboarding/onboarding_screen.dart';
import 'login_screen.dart';

/// "Vartų sargas" — patikrina, kur nukreipti vartotoją:
/// 1. Jei neprisijungęs → LoginScreen
/// 2. Jei prisijungęs, bet onboarding nebaigtas → OnboardingScreen
/// 3. Jei prisijungęs ir onboarding baigtas → MainWrapper
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _onboardingComplete = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final session = Supabase.instance.client.auth.currentSession;

    // Jei vartotojas nėra prisijungęs - rodome login
    if (session == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _onboardingComplete = false;
        });
      }
      return;
    }

    try {
      // Tikriname Supabase profilį - ar onboarding baigtas
      final response = await Supabase.instance.client
          .from('profiles')
          .select('onboarding_complete')
          .eq('id', session.user.id)
          .maybeSingle();

      bool isComplete = false;
      if (response != null && response['onboarding_complete'] == true) {
        isComplete = true;
      }

      if (mounted) {
        setState(() {
          _onboardingComplete = isComplete;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida tikrinant onboarding: $e");
      // Klaidos atveju - į onboarding (saugiau)
      if (mounted) {
        setState(() {
          _onboardingComplete = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final p = context.qortPalette;
      return Scaffold(
        backgroundColor: p.background,
        body: Center(
          child: CircularProgressIndicator(color: p.primary),
        ),
      );
    }

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const LoginScreen();
    }

    if (!_onboardingComplete) {
      return const OnboardingScreen();
    }

    return const MainWrapper();
  }
}
