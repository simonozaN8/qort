import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/qort_design_system.dart';
import 'auth_gate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  static const _logoFontSize = 56.0;

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      } else {
        await supabase.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } on AuthException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Įvyko nenumatyta klaida"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QortDesignSystem.bgBase,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'QORT',
                    style: GoogleFonts.anton(
                      fontSize: _logoFontSize,
                      color: QortDesignSystem.competition,
                      letterSpacing: _logoFontSize * 0.02,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Žaisk. Fiksuok. Kilk.',
                    style: GoogleFonts.anton(
                      fontSize: 22,
                      color: QortDesignSystem.textPrimary,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  _inputField("El. paštas", _emailCtrl, false),
                  const SizedBox(height: 14),
                  _inputField("Slaptažodis", _passCtrl, true),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QortDesignSystem.competition,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            QortDesignSystem.competition.withValues(alpha: 0.5),
                        disabledForegroundColor:
                            Colors.black.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(QortDesignSystem.radiusMd),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              _isLogin ? "PRISIJUNGTI" : "REGISTRUOTIS",
                              style: GoogleFonts.bebasNeue(
                                fontSize: 22,
                                letterSpacing: 1.2,
                                color: Colors.black,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? "Neturi paskyros? Registruokis"
                          : "Jau turi paskyrą? Prisijunk",
                      style: const TextStyle(
                        color: QortDesignSystem.textSecondary,
                      ),
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

  Widget _inputField(
    String label,
    TextEditingController ctrl,
    bool isPass,
  ) {
    return TextField(
      controller: ctrl,
      obscureText: isPass,
      style: const TextStyle(color: QortDesignSystem.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: QortDesignSystem.textSecondary),
        filled: true,
        fillColor: QortDesignSystem.bgElevated,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(QortDesignSystem.radiusMd),
          borderSide: BorderSide(color: QortDesignSystem.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(QortDesignSystem.radiusMd),
          borderSide: BorderSide(color: QortDesignSystem.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(QortDesignSystem.radiusMd),
          borderSide: const BorderSide(
            color: QortDesignSystem.competition,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
