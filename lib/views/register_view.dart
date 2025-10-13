import 'package:flutter/material.dart';
import 'package:guardian/controllers/login_controller.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LoginController _loginController = LoginController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isEmailValid(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // ==== Password Requisitos ====
  bool hasMinLength(String password) => password.length >= 8;
  bool hasUppercase(String password) => password.contains(RegExp(r'[A-Z]'));
  bool hasLowercase(String password) => password.contains(RegExp(r'[a-z]'));
  bool hasDigit(String password)     => password.contains(RegExp(r'\d'));
  bool hasSpecialChar(String password) => password.contains(RegExp(r'[!@#\$&*~_.,;:<>?\[\]()\-+=%]'));

  bool _isPasswordValid(String password) {
    return hasMinLength(password) &&
        hasUppercase(password) &&
        hasLowercase(password) &&
        hasDigit(password) &&
        hasSpecialChar(password);
  }
  // ============================

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)),
      );
      return;
    }

    if (!_isEmailValid(email)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)),
      );
      return;
    }

    if (!_isPasswordValid(password)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La contraseña debe tener al menos:\n'
            '- 8 caracteres\n'
            '- 1 mayúscula\n'
            '- 1 minúscula\n'
            '- 1 número\n'
            '- 1 símbolo especial',
            style: TextStyle(height: 1.6),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final error = await _loginController.registerWithEmail(email, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.appTitle)),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    final password = _passwordController.text;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: mediaQuery.size.height * 0.07,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  AppLocalizations.of(context)!.register,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  AppLocalizations.of(context)!.appTitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Image.asset('assets/images/guardian_logo.png', width: 120),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PasswordValidationWidget(password: password),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F2937),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          AppLocalizations.of(context)!.register,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    '${AppLocalizations.of(context)!.alreadyHaveAccount} ${AppLocalizations.of(context)!.login}',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== WIDGET VALIDACIÓN EN VIVO ===================

class PasswordValidationWidget extends StatelessWidget {
  final String password;
  const PasswordValidationWidget({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final styleOk = TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold);
    final styleBad = TextStyle(color: Colors.grey[600]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RequirementText('Mínimo 8 caracteres', password.length >= 8, styleOk, styleBad),
        _RequirementText('Al menos 1 mayúscula', password.contains(RegExp(r'[A-Z]')), styleOk, styleBad),
        _RequirementText('Al menos 1 minúscula', password.contains(RegExp(r'[a-z]')), styleOk, styleBad),
        _RequirementText('Al menos 1 número', password.contains(RegExp(r'\d')), styleOk, styleBad),
        _RequirementText('Al menos 1 símbolo especial', password.contains(RegExp(r'[!@#\$&*~_.,;:<>?\[\]()\-+=%]')), styleOk, styleBad),
      ],
    );
  }
}

class _RequirementText extends StatelessWidget {
  final String label;
  final bool fulfilled;
  final TextStyle styleOk, styleBad;

  // ignore: unused_element_parameter
  const _RequirementText(this.label, this.fulfilled, this.styleOk, this.styleBad, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(fulfilled ? Icons.check_circle : Icons.radio_button_unchecked,
            color: fulfilled ? Colors.green : Colors.grey, size: 20),
        const SizedBox(width: 6),
        Text(label, style: fulfilled ? styleOk : styleBad),
      ],
    );
  }
}
