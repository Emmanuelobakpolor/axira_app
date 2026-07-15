import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';
import '../dashboard_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/error_snackbar.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      showErrorSnackbar(context, 'Please fill in all fields.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Detect whether the user typed an email or a phone number
      final isEmail = identifier.contains('@');
      final result = await AuthService.signIn(
        email: isEmail ? identifier : null,
        phone: isEmail ? null : identifier,
        password: password,
      );
      await AuthService.saveAuthResult(result);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (mounted) showErrorSnackbar(context, e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const AuthBackButton(),
                    const SizedBox(height: 32),
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                        color: kAuthTextDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to continue',
                      style: TextStyle(fontSize: 17, color: kAuthTextGrey),
                    ),
                    const SizedBox(height: 32),
                    const AuthFieldLabel('Email or Phone Number'),
                    const SizedBox(height: 8),
                    AuthInputField(
                      controller: _identifierController,
                      hint: 'example@email.com or +2348000000000',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    const AuthFieldLabel('Password'),
                    const SizedBox(height: 8),
                    AuthInputField(
                      controller: _passwordController,
                      hint: 'Enter password',
                      obscure: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: kAuthTextGrey,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: kAuthBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AuthPrimaryButton(
                      label: 'Sign In',
                      onPressed: _onSignIn,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateAccountScreen()),
                  ),
                  child: RichText(
                    text: const TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(color: kAuthTextGrey, fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Create one',
                          style: TextStyle(
                              color: kAuthBlue, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
