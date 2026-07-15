import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'setup_profile_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/error_snackbar.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String sessionId;
  final String email;

  const VerifyOtpScreen({
    super.key,
    required this.sessionId,
    required this.email,
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;

  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _clearBoxes() {
    for (final c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) _focusNodes[0].requestFocus();
    setState(() {});
  }

  Future<void> _onVerify() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.verifyOtp(sessionId: widget.sessionId, otp: _otp);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetupProfileScreen(sessionId: widget.sessionId),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) showErrorSnackbar(context, e.message);
      _clearBoxes();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onResend() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.resendOtp(sessionId: widget.sessionId);
      if (!mounted) return;
      _showInfo('A new code has been sent to ${widget.email}');
      _clearBoxes();
    } on AuthException catch (e) {
      if (mounted) showErrorSnackbar(context, e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _otp.length == 4;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const AuthBackButton(),
                    const SizedBox(height: 32),
                    const Text(
                      'Verify OTP',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                        color: kAuthTextDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the 4 digit code sent to ${widget.email}',
                      style: const TextStyle(fontSize: 17, color: kAuthTextGrey),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        4,
                        (i) => _OtpBox(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          onChanged: (v) => _onChanged(i, v),
                          isFilled: _controllers[i].text.isNotEmpty,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : _onResend,
                        child: const Text(
                          "Didn't receive code? Resend",
                          style: TextStyle(color: kAuthBlue, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AuthPrimaryButton(
                      label: 'Verify',
                      onPressed: isComplete ? _onVerify : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isFilled;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isFilled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 58,
      decoration: BoxDecoration(
        color: kAuthFieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFilled ? kAuthBlue : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: kAuthTextDark,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
