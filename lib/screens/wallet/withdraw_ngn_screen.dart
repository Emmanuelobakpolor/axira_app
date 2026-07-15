import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart' show AuthService, kSessionExpiredError;
import '../../services/wallet_service.dart';
import '../auth/sign_in_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);
const _kGreen = Color(0xFF16A34A);

// Fallback list of major Nigerian banks with their Flutterwave bank codes.
// Used when the FLW API cannot be reached.
const _kFallbackBanks = [
  ('Access Bank', '044'),
  ('Citibank Nigeria', '023'),
  ('Ecobank Nigeria', '050'),
  ('Fidelity Bank', '070'),
  ('First Bank of Nigeria', '011'),
  ('First City Monument Bank', '214'),
  ('Guaranty Trust Bank', '058'),
  ('Heritage Bank', '030'),
  ('Jaiz Bank', '301'),
  ('Keystone Bank', '082'),
  ('Kuda Bank', '50211'),
  ('Moniepoint MFB', '50515'),
  ('OPay', '100004'),
  ('PalmPay', '100033'),
  ('Parallex Bank', '104'),
  ('Polaris Bank', '076'),
  ('Providus Bank', '101'),
  ('Stanbic IBTC Bank', '221'),
  ('Standard Chartered', '068'),
  ('Sterling Bank', '232'),
  ('Union Bank of Nigeria', '032'),
  ('United Bank for Africa', '033'),
  ('Unity Bank', '215'),
  ('VFD Microfinance Bank', '566'),
  ('Wema Bank', '035'),
  ('Zenith Bank', '057'),
];

class WithdrawNgnScreen extends StatefulWidget {
  const WithdrawNgnScreen({super.key});

  @override
  State<WithdrawNgnScreen> createState() => _WithdrawNgnScreenState();
}

class _WithdrawNgnScreenState extends State<WithdrawNgnScreen> {
  double? _balance;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final info = await WalletService.getWallet();
      if (mounted) {
        setState(() { _balance = info.ngnBalance; _loading = false; });
        _showWithdrawalSheet();
      }
    } on WalletException catch (e) {
      if (mounted) setState(() { _loadError = e.message; _loading = false; });
    }
  }

  void _showWithdrawalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WithdrawalSheet(
        balance: _balance ?? 0,
        onClose: () => Navigator.pop(context),
        onCancel: () => Navigator.pop(context),
        onSuccess: (amount) {
          Navigator.pop(context);
          setState(() => _balance = (_balance ?? 0) - amount);
          _showSuccessDialog(amount);
        },
      ),
    );
  }

  void _showSuccessDialog(double amount) {
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
                decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: _kGreen, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Withdrawal Initiated',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: _kGrey, height: 1.6),
                  children: [
                    const TextSpan(text: 'Your withdrawal of '),
                    TextSpan(
                      text: '₦${amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _kDark),
                    ),
                    const TextSpan(
                      text: ' has been sent to Flutterwave for processing. It typically arrives within 24 hours.',
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
                    'Okay, Thanks',
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
          'Withdraw NGN',
          style: TextStyle(color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorView(
                  message: _loadError!,
                  onRetry: () {
                    setState(() { _loading = true; _loadError = null; });
                    _loadBalance();
                  },
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available Balance', style: TextStyle(fontSize: 13, color: _kGrey)),
          const SizedBox(height: 6),
          Text(
            '₦${(_balance ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _kDark),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _showWithdrawalSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Withdraw Funds',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Withdrawal Bottom Sheet ──────────────────────────────────────────────────

class _WithdrawalSheet extends StatefulWidget {
  final double balance;
  final VoidCallback onClose;
  final VoidCallback onCancel;
  final void Function(double amount) onSuccess;

  const _WithdrawalSheet({
    required this.balance,
    required this.onClose,
    required this.onCancel,
    required this.onSuccess,
  });

  @override
  State<_WithdrawalSheet> createState() => _WithdrawalSheetState();
}

class _WithdrawalSheetState extends State<_WithdrawalSheet> {
  // Bank state
  List<NigerianBank> _banks = [];
  bool _banksLoading = true;
  NigerianBank? _selectedBank;

  // Account state
  final _acctCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String? _resolvedAccountName;
  bool _resolving = false;
  String? _resolveError;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  @override
  void dispose() {
    _acctCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await WalletService.getBanks();
      if (mounted) setState(() { _banks = banks; _banksLoading = false; });
    } on WalletException {
      // Fall back to hardcoded list on API failure
      if (mounted) {
        setState(() {
          _banks = _kFallbackBanks
              .map((b) => NigerianBank(name: b.$1, code: b.$2))
              .toList();
          _banksLoading = false;
        });
      }
    }
  }

  Future<void> _resolveAccount() async {
    if (_selectedBank == null || _acctCtrl.text.length != 10) return;
    setState(() { _resolving = true; _resolveError = null; _resolvedAccountName = null; });
    try {
      final name = await WalletService.resolveAccount(_acctCtrl.text.trim(), _selectedBank!.code);
      if (mounted) setState(() { _resolvedAccountName = name; _resolving = false; });
    } on WalletException catch (e) {
      if (mounted) setState(() { _resolveError = e.message; _resolving = false; });
    }
  }

  bool get _canProceed =>
      _selectedBank != null &&
      _acctCtrl.text.length == 10 &&
      _resolvedAccountName != null &&
      _amountCtrl.text.isNotEmpty;

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < 500) {
      setState(() => _submitError = 'Minimum withdrawal is ₦500');
      return;
    }
    if (amount > widget.balance) {
      setState(() => _submitError = 'Amount exceeds your available balance');
      return;
    }

    setState(() { _submitting = true; _submitError = null; });
    try {
      await WalletService.requestWithdrawal(
        amount: amount,
        accountName: _resolvedAccountName!,
        bankName: _selectedBank!.name,
        bankCode: _selectedBank!.code,
        accountNumber: _acctCtrl.text.trim(),
      );
      if (mounted) widget.onSuccess(amount);
    } on WalletException catch (e) {
      if (mounted) setState(() { _submitError = e.message; _submitting = false; });
    }
  }

  void _pickBank() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BankPickerSheet(
        banks: _banks,
        onPick: (bank) {
          setState(() {
            _selectedBank = bank;
            _resolvedAccountName = null;
            _resolveError = null;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Withdrawal Details',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Available: ₦${widget.balance.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, color: _kGrey),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Bank picker ──
                  const Text('Bank', style: TextStyle(fontSize: 12, color: _kGrey)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _banksLoading ? null : _pickBank,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: _selectedBank != null ? _kBlue : _kBorder)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _banksLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
                                  )
                                : Text(
                                    _selectedBank?.name ?? 'Select bank',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedBank != null ? _kDark : _kGrey,
                                    ),
                                  ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: _kGrey, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Account number + resolve ──
                  const Text('Account Number', style: TextStyle(fontSize: 12, color: _kGrey)),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _acctCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          onChanged: (_) => setState(() {
                            _resolvedAccountName = null;
                            _resolveError = null;
                          }),
                          style: const TextStyle(fontSize: 15, color: _kDark, fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(
                            border: UnderlineInputBorder(borderSide: BorderSide(color: _kBorder)),
                            focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: _kBlue, width: 1.5)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kBorder)),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: (_selectedBank != null && _acctCtrl.text.length == 10 && !_resolving)
                              ? _resolveAccount
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue,
                            disabledBackgroundColor: _kBlue.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: _resolving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Verify', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),

                  // ── Resolved account name ──
                  if (_resolvedAccountName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: _kGreen, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _resolvedAccountName!,
                            style: const TextStyle(fontSize: 13, color: _kGreen, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  if (_resolveError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _resolveError!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // ── Amount ──
                  const Text('Amount (₦)', style: TextStyle(fontSize: 12, color: _kGrey)),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    onChanged: (_) => setState(() => _submitError = null),
                    style: const TextStyle(fontSize: 15, color: _kDark, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(borderSide: BorderSide(color: _kBorder)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _kBlue, width: 1.5)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kBorder)),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  if (_submitError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_submitError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                    ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_canProceed && !_submitting) ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        disabledBackgroundColor: _kBlue.withValues(alpha: 0.45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Proceed',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: widget.onCancel,
                      child: const Text(
                        'Cancel Withdrawal',
                        style: TextStyle(fontSize: 14, color: _kGrey, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bank Picker Sheet ────────────────────────────────────────────────────────

class _BankPickerSheet extends StatefulWidget {
  final List<NigerianBank> banks;
  final void Function(NigerianBank) onPick;
  const _BankPickerSheet({required this.banks, required this.onPick});

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<NigerianBank> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.banks;
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? widget.banks
            : widget.banks.where((b) => b.name.toLowerCase().contains(q)).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Bank',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kDark),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search banks…',
                    hintStyle: const TextStyle(color: _kGrey, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: _kGrey, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final bank = _filtered[i];
                return ListTile(
                  title: Text(bank.name, style: const TextStyle(fontSize: 14, color: _kDark)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPick(bank);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

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
