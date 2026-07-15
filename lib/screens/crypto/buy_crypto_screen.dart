import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart' show AuthException;
import '../../services/crypto_service.dart';
import '../../utils/session_guard.dart';
import '../../widgets/coin_logo.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/error_snackbar.dart';
import 'crypto_pending_screen.dart';

String _newIdempKey() {
  final r = Random.secure();
  return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
}

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);
const _kBlueBg = Color(0xFFEBF2FF);
const _kDisabled = Color(0xFFBFD7FC);


String _fmtNum(double v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intStr = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '$intStr.${parts[1]}';
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class BuyCryptoScreen extends StatefulWidget {
  const BuyCryptoScreen({super.key});

  @override
  State<BuyCryptoScreen> createState() => _BuyCryptoScreenState();
}

class _BuyCryptoScreenState extends State<BuyCryptoScreen> {
  bool _isBuy = true;
  String? _token;
  final _qtyCtrl = TextEditingController();

  List<CoinInfo> _coins = [];
  Map<String, double> _prices = {};
  Map<String, CryptoFees> _fees = {};
  bool _loading = true;
  String _loadError = '';

  @override
  void initState() {
    super.initState();
    _loadPricesAndFees();
  }

  Future<void> _loadPricesAndFees() async {
    setState(() {
      _loading = true;
      _loadError = '';
    });
    try {
      final results = await Future.wait([
        CryptoService.getPrices(),
        CryptoService.getFees(),
      ]);
      if (!mounted) return;
      final pricesData = results[0] as CryptoPricesData;
      setState(() {
        _coins = pricesData.coins;
        _prices = pricesData.prices;
        _fees = results[1] as Map<String, CryptoFees>;
        _loading = false;
      });
    } on CryptoException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  double get _rate => _prices[_token] ?? 0;
  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;
  double get _baseNgn => _qty * _rate;

  CryptoFees? get _currentFees => _fees[_isBuy ? 'buy' : 'sell'];

  double get _feeNgn {
    final f = _currentFees;
    if (f == null || _baseNgn == 0) return 0;
    const ngNperUsd = 1600.0;
    return f.flatUsd * ngNperUsd + _baseNgn * f.percent / 100;
  }

  // Buy: user pays base + fee; Sell: user receives base - fee
  double get _totalNgn => _isBuy ? _baseNgn + _feeNgn : _baseNgn - _feeNgn;

  bool get _canContinue =>
      _token != null && _qty > 0 && _rate > 0 && !_loading;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _openTokenSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TokenSheet(
        selected: _token,
        coins: _coins,
        onSelect: (tok) {
          setState(() => _token = tok);
          Navigator.pop(context);
        },
      ),
    );
  }

  bool _quoting = false;

  Future<void> _onContinue() async {
    if (_token == null || _qty <= 0 || _rate <= 0 || _quoting) return;
    setState(() => _quoting = true);

    try {
      final quote = await CryptoService.createQuote(
        type: _isBuy ? 'buy' : 'sell',
        coin: _token!,
        amount: _qty,
      );
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _OrderSheet(
          isBuy: _isBuy,
          quote: quote,
          token: _token!,
          qty: _qty,
          onConfirm: () => Navigator.pop(context),
          onCancel: () => Navigator.pop(context),
        ),
      );
    } on AuthException catch (_) {
      if (!mounted) return;
      await redirectToSignIn(context);
    } on CryptoException catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, e.message);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
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
          'Crypto',
          style: TextStyle(
              color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh, color: _kGrey, size: 20),
              onPressed: _loadPricesAndFees,
              tooltip: 'Refresh prices',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : _loadError.isNotEmpty
              ? _ErrorState(
                  message: _loadError, onRetry: _loadPricesAndFees)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BuySellToggle(
                  isBuy: _isBuy,
                  onBuy: () => setState(() => _isBuy = true),
                  onSell: () => setState(() => _isBuy = false),
                ),
                const SizedBox(height: 24),

                // ── Select Token ───────────────────────────────────────────
                GestureDetector(
                  onTap: _openTokenSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _token ?? 'Select Token',
                            style: TextStyle(
                              fontSize: 14,
                              color: _token != null ? _kDark : _kGrey,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: _kGrey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Quantity ───────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14, color: _kDark),
                    decoration: InputDecoration(
                      hintText: _isBuy
                          ? 'Enter quantity to buy'
                          : 'Enter quantity to sell',
                      hintStyle:
                          const TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Min: 0.00',
                  style: TextStyle(fontSize: 12, color: _kBlue),
                ),
                const SizedBox(height: 16),

                // ── Rate ──────────────────────────────────────────────────
                _InfoBox(
                    label: 'Rate',
                    value: _rate == 0
                        ? '—'
                        : '₦${_fmtNum(_rate)} / $_token'),
                const SizedBox(height: 10),

                // ── Fee ───────────────────────────────────────────────────
                if (_qty > 0 && _rate > 0) ...[
                  _InfoBox(
                      label: 'Fee',
                      value: '₦${_fmtNum(_feeNgn)}'),
                  const SizedBox(height: 10),
                ],

                // ── Total ─────────────────────────────────────────────────
                _InfoBox(
                  label: _isBuy ? 'Total NGN to pay' : 'You will receive (NGN)',
                  value: _totalNgn <= 0 ? '—' : '₦${_fmtNum(_totalNgn)}',
                  highlighted: true,
                ),
              ],
            ),
          ),
        ),

        // ── Action Buttons ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _canContinue && !_quoting ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    disabledBackgroundColor: _kBlue.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _quoting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                          'Continue',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kDisabled,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Cancel Transaction',
                    style: TextStyle(
                        color: _kBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kGrey, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info Box ─────────────────────────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;

  const _InfoBox({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kBlueBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: _kBlue)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: _kBlue,
                  fontWeight:
                      highlighted ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ─── Buy/Sell Toggle ──────────────────────────────────────────────────────────

class _BuySellToggle extends StatelessWidget {
  final bool isBuy;
  final VoidCallback onBuy;
  final VoidCallback onSell;

  const _BuySellToggle(
      {required this.isBuy, required this.onBuy, required this.onSell});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _Tab(label: 'Buy Crypto', active: isBuy, onTap: onBuy),
          _Tab(label: 'Sell Crypto', active: !isBuy, onTap: onSell),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? _kBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : _kGrey,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Token Sheet ──────────────────────────────────────────────────────────────

class _TokenSheet extends StatefulWidget {
  final String? selected;
  final List<CoinInfo> coins;
  final ValueChanged<String> onSelect;

  const _TokenSheet({
    required this.selected,
    required this.coins,
    required this.onSelect,
  });

  @override
  State<_TokenSheet> createState() => _TokenSheetState();
}

class _TokenSheetState extends State<_TokenSheet> {
  String _query = '';

  List<CoinInfo> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.coins;
    return widget.coins
        .where((c) =>
            c.symbol.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;
    final results = _filtered;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Select Token',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _kDark)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 14, color: _kDark),
                decoration: const InputDecoration(
                  hintText: 'Search coin name or symbol',
                  hintStyle: TextStyle(fontSize: 14, color: _kGrey),
                  prefixIcon: Icon(Icons.search, color: _kGrey, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No coins match your search.',
                    style: TextStyle(fontSize: 13, color: _kGrey)),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final coin = results[i];
                  return InkWell(
                    onTap: () => widget.onSelect(coin.symbol),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          CoinLogo(
                            logoUrl: coin.logoUrl,
                            letter: coin.letter,
                            letterColor: coin.color,
                            backgroundColor:
                                coin.color.withValues(alpha: 0.15),
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(coin.name,
                                    style: const TextStyle(
                                        fontSize: 14, color: _kDark)),
                                if (coin.priceNgn > 0)
                                  Text('₦${_fmtNum(coin.priceNgn)}',
                                      style: const TextStyle(
                                          fontSize: 12, color: _kGrey)),
                              ],
                            ),
                          ),
                          if (coin.symbol == widget.selected)
                            const Icon(Icons.check, color: _kBlue, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Order Confirmation Sheet ─────────────────────────────────────────────────

class _OrderSheet extends StatefulWidget {
  final bool isBuy;
  final String token;
  final double qty;
  final CryptoQuote quote;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _OrderSheet({
    required this.isBuy,
    required this.token,
    required this.qty,
    required this.quote,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  bool _submitting = false;
  File? _proofFile;
  BuyOrderResult? _buyResult;
  SellOrderResult? _sellResult;
  String _error = '';

  late int _countdown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _countdown = widget.quote.expiresIn;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) _countdown--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _quoteExpired => _countdown <= 0;

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _proofFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (_submitting || _quoteExpired) return;
    setState(() {
      _submitting = true;
      _error = '';
    });

    final ikey = _newIdempKey();
    try {
      if (widget.isBuy) {
        final result = await CryptoService.createBuyOrder(
          quoteId: widget.quote.quoteId,
          idempotencyKey: ikey,
        );
        if (!mounted) return;
        await _handleBuyResult(result);
      } else {
        final result = await CryptoService.createSellOrder(
          quoteId: widget.quote.quoteId,
          idempotencyKey: ikey,
        );
        if (!mounted) return;
        setState(() => _sellResult = result);
      }
    } on AuthException catch (_) {
      if (!mounted) return;
      await redirectToSignIn(context);
    } on CryptoException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Routes a freshly-created buy order to the right next step:
  /// pay in-app via Flutterwave, fall back to manual bank transfer, or
  /// (if the NGN wallet balance already covered it) finish immediately.
  Future<void> _handleBuyResult(BuyOrderResult result) async {
    if (result.needsPayment && result.flutterwave != null) {
      await _payWithFlutterwave(result);
      return;
    }
    if (result.bankDetails != null) {
      // Flutterwave isn't configured at all — manual bank transfer + proof.
      setState(() => _buyResult = result);
      return;
    }
    // Paid instantly from the NGN wallet balance — nothing left to do.
    _finishBuy(result);
  }

  /// Launches Flutterwave's in-app payment sheet, then asks the backend to
  /// verify the charge server-side before treating the order as paid —
  /// nothing is ever assumed successful on the client's say-so alone.
  Future<void> _payWithFlutterwave(BuyOrderResult result) async {
    final fw = result.flutterwave!;
    try {
      final flutterwave = Flutterwave(
        publicKey: fw.publicKey,
        currency: 'NGN',
        redirectUrl: 'https://flutterwave.com',
        txRef: fw.txRef,
        amount: fw.amount.toStringAsFixed(2),
        customer: Customer(
          name: fw.customerName,
          phoneNumber: fw.customerPhone,
          email: fw.customerEmail,
        ),
        paymentOptions: 'card,banktransfer,ussd',
        customization: Customization(
          title: 'Buy ${result.coin} on Axira',
          description: '${result.coinAmount} ${result.coin}',
        ),
        isTestMode: false,
      );

      if (!mounted) return;
      final response = await flutterwave.charge(context);
      if (!mounted) return;

      if (response.success != true) {
        setState(() => _error = response.status == 'cancelled'
            ? 'Payment cancelled.'
            : 'Payment failed. Please try again.');
        return;
      }

      final verified = await CryptoService.verifyBuyPayment(result.reference);
      if (!mounted) return;
      _finishBuy(verified);
    } on AuthException catch (_) {
      if (!mounted) return;
      await redirectToSignIn(context);
    } on CryptoException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Payment error: $e');
    }
  }

  /// Reacts to a confirmed order's final status — only ever "completed"
  /// after the backend itself has verified payment and executed the buy.
  void _finishBuy(BuyOrderResult result) {
    if (result.status == 'completed') {
      widget.onConfirm();
      _showPurchaseSuccess();
    } else if (result.status == 'failed') {
      final reason = result.errorDetail?.isNotEmpty == true
          ? result.errorDetail!
          : 'Please contact support with reference ${result.reference}.';
      final refundNote = result.refunded
          ? ' Your ₦${result.totalNgn.toStringAsFixed(2)} has been refunded to your wallet.'
          : ' No refund has been issued automatically for this reference — contact support.';
      setState(() => _error = 'Purchase failed: $reason$refundNote');
    } else {
      // Rare: payment confirmed but the Quidax order hasn't filled yet.
      widget.onConfirm();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const CryptoTransactionPendingScreen(),
        ),
      );
    }
  }

  void _showPurchaseSuccess() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PurchaseSuccessSheet(
        onDone: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    );
  }

  Future<void> _uploadProofAndFinish() async {
    if (_proofFile == null || _buyResult == null) return;
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await CryptoService.uploadProof(
        reference: _buyResult!.reference,
        proof: _proofFile!,
      );
      if (!mounted) return;
      widget.onConfirm();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const CryptoTransactionPendingScreen()),
        );
      }
    } on AuthException catch (_) {
      if (!mounted) return;
      await redirectToSignIn(context);
    } on CryptoException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetH = MediaQuery.of(context).size.height * 0.90;

    return SizedBox(
      height: sheetH,
      child: Column(
        children: [
          _SheetHandle(),
          _SheetHeader(
            title: widget.isBuy ? 'Buy Order' : 'Sell Order',
            subtitle: widget.isBuy
                ? 'Preview your buy order details below'
                : 'Preview your sell order details below',
            onClose: widget.onCancel,
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _buildBody(),
            ),
          ),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // After order created: show bank details (buy) or deposit address (sell)
    if (_buyResult != null) {
      return _BuyConfirmBody(
        result: _buyResult!,
        proofFile: _proofFile,
        onPickProof: _pickProof,
      );
    }
    if (_sellResult != null) {
      return _SellConfirmBody(result: _sellResult!);
    }

    // Pre-submission: show summary + countdown timer
    final q = widget.quote;
    final baseNgn = widget.qty * q.rateNgn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Once a real failure is showing below, the countdown banner is
        // stale noise — the quote was already consumed server-side long
        // before it visually expired (e.g. during a Flutterwave charge).
        if (_error.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _quoteExpired
                  ? Colors.red.withValues(alpha: 0.08)
                  : _kBlueBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _quoteExpired ? Colors.red.shade200 : _kBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _quoteExpired ? Icons.timer_off : Icons.timer,
                  size: 16,
                  color: _quoteExpired ? Colors.red : _kBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  _quoteExpired
                      ? 'Quote expired — please go back and try again.'
                      : 'Rate locked for $_countdown seconds',
                  style: TextStyle(
                    fontSize: 12,
                    color: _quoteExpired ? Colors.red : _kBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        _OrderRow(label: 'Token:', value: widget.token),
        _OrderRow(label: 'Rate:', value: '₦${_fmtNum(q.rateNgn)}'),
        _OrderRow(label: 'Quantity:', value: _fmtNum(widget.qty)),
        _OrderRow(
          label: widget.isBuy ? 'Subtotal:' : 'Gross proceeds:',
          value: '₦${_fmtNum(baseNgn)}',
        ),
        _OrderRow(label: 'Fee:', value: '₦${_fmtNum(q.feeNgn)}'),
        _OrderRow(
          label: widget.isBuy ? 'Total to pay (NGN):' : 'You receive (NGN):',
          value: '₦${_fmtNum(q.totalNgn)}',
          bold: true,
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          ErrorBanner(message: _error),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActions() {
    // After buy order created: show "I paid" button
    if (_buyResult != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _proofFile != null && !_submitting
                    ? _uploadProofAndFinish
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  disabledBackgroundColor: _kBlue.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('I have made the payment',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
            Text('Please upload proof first',
                style: const TextStyle(fontSize: 12, color: _kGrey)),
          ],
        ),
      );
    }

    // After sell order created: show done button
    if (_sellResult != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              widget.onConfirm();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const CryptoTransactionPendingScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Done',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    // Pre-submission buttons
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _submitting || _quoteExpired ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                disabledBackgroundColor: _kBlue.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      widget.isBuy ? 'Place Buy Order' : 'Place Sell Order',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _submitting ? null : widget.onCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDisabled,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Cancel Transaction',
                style: TextStyle(
                    color: _kBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Purchase Success Sheet ───────────────────────────────────────────────────

class _PurchaseSuccessSheet extends StatelessWidget {
  final VoidCallback onDone;
  const _PurchaseSuccessSheet({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kBlue.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF0E24A0), Color(0xFF60A5FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 38),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Purchase Successful!',
            style:
                TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Your crypto has been credited to your wallet.',
            style: TextStyle(fontSize: 14, color: _kGrey, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Buy Confirm Body ─────────────────────────────────────────────────────────

class _BuyConfirmBody extends StatelessWidget {
  final BuyOrderResult result;
  final File? proofFile;
  final VoidCallback onPickProof;

  const _BuyConfirmBody(
      {required this.result,
      required this.proofFile,
      required this.onPickProof});

  @override
  Widget build(BuildContext context) {
    final bank = result.bankDetails;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OrderRow(label: 'Reference:', value: result.reference),
        _OrderRow(label: 'Token:', value: result.coin),
        _OrderRow(label: 'Quantity:', value: _fmtNum(result.coinAmount)),
        _OrderRow(
            label: 'Total to pay:',
            value: '₦${_fmtNum(result.totalNgn)}',
            bold: true),
        const SizedBox(height: 16),

        // Bank details — only shown in manual (non-Flutterwave) flow
        if (bank != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEBF4FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFD7FC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please make the payment to the account below:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kBlue),
                ),
                const SizedBox(height: 8),
                _InfoLine(
                    label: 'Account Number:',
                    value: bank.accountNumber.isEmpty
                        ? 'Contact support'
                        : bank.accountNumber),
                _InfoLine(
                    label: 'Account Name:',
                    value: bank.accountName.isEmpty
                        ? 'Axira'
                        : bank.accountName),
                _InfoLine(
                    label: 'Bank Name:',
                    value: bank.bankName.isEmpty
                        ? 'Contact support'
                        : bank.bankName),
                const SizedBox(height: 8),
                const Text(
                  'Use your reference as transfer narration.',
                  style: TextStyle(
                      fontSize: 12, color: _kBlue, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Upload Proof of Payment',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kDark),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onPickProof,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      proofFile != null
                          ? proofFile!.path.split('/').last
                          : 'Upload proof of payment',
                      style: TextStyle(
                          fontSize: 13,
                          color: proofFile != null ? _kDark : _kGrey),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_file, size: 14, color: _kDark),
                        SizedBox(width: 4),
                        Text('Browse',
                            style: TextStyle(
                                fontSize: 12,
                                color: _kDark,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

// ─── Sell Confirm Body ────────────────────────────────────────────────────────

class _SellConfirmBody extends StatelessWidget {
  final SellOrderResult result;
  const _SellConfirmBody({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OrderRow(label: 'Reference:', value: result.reference),
        _OrderRow(label: 'Token:', value: result.coin),
        _OrderRow(label: 'Quantity:', value: _fmtNum(result.coinAmount)),
        _OrderRow(
            label: 'You will receive:',
            value: '₦${_fmtNum(result.payoutNgn)}',
            bold: true),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEBF4FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFD7FC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send your crypto to the address below:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kBlue),
              ),
              const SizedBox(height: 8),
              _InfoLine(
                  label: 'Deposit Address:',
                  value: result.depositAddress.isEmpty
                      ? 'Contact support for address'
                      : result.depositAddress),
              _InfoLine(label: 'Network:', value: result.coin),
              const SizedBox(height: 8),
              const Text(
                'Your NGN payout will be credited immediately.',
                style: TextStyle(
                    fontSize: 12, color: _kBlue, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── Sheet helpers ────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: _kBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const _SheetHeader(
      {required this.title,
      required this.subtitle,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _kDark)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: _kGrey)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close,
                  size: 16, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _OrderRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: _kGrey)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w600,
                  color: _kDark)),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label $value',
          style: const TextStyle(fontSize: 13, color: _kBlue)),
    );
  }
}
