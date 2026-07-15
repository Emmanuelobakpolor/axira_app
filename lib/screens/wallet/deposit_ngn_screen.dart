import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterwave_standard/flutterwave.dart';

import '../../services/auth_service.dart' show AuthService, kSessionExpiredError;
import '../../services/wallet_service.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/error_state_view.dart';
import '../auth/sign_in_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kGreen = Color(0xFF16A34A);


class DepositNgnScreen extends StatefulWidget {
  const DepositNgnScreen({super.key});

  @override
  State<DepositNgnScreen> createState() => _DepositNgnScreenState();
}

class _DepositNgnScreenState extends State<DepositNgnScreen> {
  final _amountCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _verifyingMsg;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String _generateTxRef() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'AXIRA-$ts-$rand';
  }

  String _formatNgn(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},',
    );
    return '₦$intPart.${parts[1]}';
  }

  Future<void> _onPay() async {
    final raw = _amountCtrl.text.trim().replaceAll(',', '');
    final amount = double.tryParse(raw);
    if (amount == null || amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount (minimum ₦100)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = AuthService.currentUserNotifier.value;
    if (user == null) {
      setState(() => _error = kSessionExpiredError);
      return;
    }

    setState(() { _loading = true; _error = null; _verifyingMsg = 'Preparing payment…'; });

    final txRef = _generateTxRef();

    // Step 1: register pending tx on backend — returns the FLW public key
    String publicKey;
    try {
      publicKey = await WalletService.initiateDeposit(amount, txRef);
    } on WalletException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _verifyingMsg = null; _error = e.message; });
      return;
    }

    if (!mounted) return;
    setState(() => _verifyingMsg = null);

    // Step 2: launch Flutterwave in-app payment sheet
    try {
      final flutterwave = Flutterwave(
        publicKey: publicKey,
        currency: 'NGN',
        redirectUrl: 'https://flutterwave.com',
        txRef: txRef,
        amount: amount.toStringAsFixed(2),
        customer: Customer(
          name: user.fullName,
          phoneNumber: user.phone,
          email: user.email,
        ),
        paymentOptions: 'card,banktransfer,ussd',
        customization: Customization(
          title: 'Axira Top-Up',
          description: 'Add money to your NGN wallet',
        ),
        isTestMode: false, // set true if using FLWPUBK_TEST- keys, false for live FLWPUBK- keys
      );

      if (!mounted) return;
      final response = await flutterwave.charge(context);

      if (!mounted) return;

      if (response.success != true) {
        setState(() { _loading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.status == 'cancelled'
                  ? 'Payment cancelled.'
                  : 'Payment failed. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Step 3: verify with backend and get new balance
      setState(() => _verifyingMsg = 'Verifying payment…');
      double newBalance;
      try {
        newBalance = await WalletService.verifyPayment(txRef);
      } on WalletException catch (e) {
        if (!mounted) return;
        setState(() { _loading = false; _verifyingMsg = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() { _loading = false; _verifyingMsg = null; });
      _showSuccess(amount, newBalance);

    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _verifyingMsg = null; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment error: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showSuccess(double amount, double newBalance) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: _kGreen, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Top-Up Successful!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: _kGrey, height: 1.6),
                  children: [
                    TextSpan(
                      text: _formatNgn(amount),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _kDark),
                    ),
                    const TextSpan(text: ' has been added to your wallet.\n\nNew balance: '),
                    TextSpan(
                      text: _formatNgn(newBalance),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _kGreen),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Top-Up',
          style: TextStyle(color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _error != null
          ? _ErrorView(
              message: _error!,
              onRetry: () => setState(() => _error = null),
            )
          : Stack(
              children: [
                _buildBody(),
                if (_loading)
                  Container(
                    color: Colors.black26,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: _kBlue),
                            if (_verifyingMsg != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _verifyingMsg!,
                                style: const TextStyle(fontSize: 14, color: _kDark),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F3FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD0D7F5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: _kBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instant Top-Up',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kDark),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pay with card, bank transfer, or USSD. Your wallet is credited instantly.',
                              style: TextStyle(fontSize: 12, color: _kGrey, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Amount',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kDark),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _kDark),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixText: '₦ ',
                    prefixStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _kDark,
                    ),
                    hintText: '0.00',
                    hintStyle: const TextStyle(color: _kGrey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _kBlue, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Minimum: ₦100', style: TextStyle(fontSize: 12, color: _kGrey)),
                const SizedBox(height: 28),
                const Divider(color: Color(0xFFE5E7EB)),
                const SizedBox(height: 20),
                const Text(
                  'Payment Options',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey),
                ),
                const SizedBox(height: 12),
                _PayOption(icon: Icons.credit_card_rounded, label: 'Debit / Credit Card'),
                const SizedBox(height: 10),
                _PayOption(icon: Icons.account_balance_rounded, label: 'Bank Transfer'),
                const SizedBox(height: 10),
                _PayOption(icon: Icons.phone_android_rounded, label: 'USSD'),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _onPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                disabledBackgroundColor: _kBlue.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Pay with Flutterwave',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PayOption extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PayOption({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _kBlue),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 14, color: _kDark)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isSessionExpired = message == kSessionExpiredError;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: _kGrey), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isSessionExpired
                  ? () async {
                      final nav = Navigator.of(context);
                      await AuthService.clearSession();
                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                        (_) => false,
                      );
                    }
                  : onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, elevation: 0),
              child: Text(
                isSessionExpired ? 'Sign In' : 'Retry',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
