import 'dart:async';
import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart' show AuthException;
import '../../services/crypto_service.dart';
import '../../utils/session_guard.dart';
import '../../widgets/coin_logo.dart';
import 'crypto_pending_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);
const _kDisabled = Color(0xFFBFD7FC);

String _fmt(double v) {
  if (v == 0) return '0';
  if (v < 0.0001) return v.toStringAsFixed(8);
  if (v == v.truncateToDouble()) {
    return v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
  return v.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

String _fmtNgn(double v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intStr = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '₦$intStr.${parts[1]}';
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class SwapCryptoScreen extends StatefulWidget {
  const SwapCryptoScreen({super.key});

  @override
  State<SwapCryptoScreen> createState() => _SwapCryptoScreenState();
}

class _SwapCryptoScreenState extends State<SwapCryptoScreen> {
  String? _fromToken;
  String? _toToken;
  final _amountCtrl = TextEditingController();

  List<CoinInfo> _coins = [];
  Map<String, double> _prices = {};
  CryptoFees? _swapFee;
  bool _loading = true;
  String _loadError = '';

  bool _quoting = false;
  String _submitError = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
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
      final fees = results[1] as Map<String, CryptoFees>;
      setState(() {
        _coins = pricesData.coins;
        _prices = pricesData.prices;
        _swapFee = fees['swap'];
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

  CoinInfo? _coin(String? symbol) {
    if (symbol == null) return null;
    try {
      return _coins.firstWhere((c) => c.symbol == symbol);
    } catch (_) {
      return null;
    }
  }

  double get _fromRate => _prices[_fromToken] ?? 0;
  double get _toRate => _prices[_toToken] ?? 0;
  double get _amount => double.tryParse(_amountCtrl.text) ?? 0;

  double get _fromNgnValue => _amount * _fromRate;

  double get _feeNgn {
    final f = _swapFee;
    if (f == null || _fromNgnValue == 0) return 0;
    const ngNperUsd = 1600.0;
    return f.flatUsd * ngNperUsd + _fromNgnValue * f.percent / 100;
  }

  double get _netNgn => (_fromNgnValue - _feeNgn).clamp(0, double.infinity);

  double get _receiveAmount =>
      (_toRate > 0 && _netNgn > 0) ? _netNgn / _toRate : 0;

  bool get _canSwap =>
      _fromToken != null &&
      _toToken != null &&
      _fromToken != _toToken &&
      _amount > 0 &&
      _fromRate > 0 &&
      _toRate > 0 &&
      !_loading &&
      !_quoting;

  void _swapTokens() {
    setState(() {
      final tmp = _fromToken;
      _fromToken = _toToken;
      _toToken = tmp;
    });
  }

  void _openFromSheet() => _openTokenSheet(
        excludeSymbol: _toToken,
        onSelect: (sym) => setState(() => _fromToken = sym),
      );

  void _openToSheet() => _openTokenSheet(
        excludeSymbol: _fromToken,
        onSelect: (sym) => setState(() => _toToken = sym),
      );

  void _openTokenSheet({
    String? excludeSymbol,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TokenSelectSheet(
        excludeSymbol: excludeSymbol,
        coins: _coins,
        onSelect: (sym) {
          onSelect(sym);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _onSwap() async {
    if (!_canSwap) return;
    setState(() {
      _quoting = true;
      _submitError = '';
    });
    try {
      final quote = await CryptoService.createQuote(
        type: 'swap',
        coin: _fromToken!,
        amount: _amount,
        toCoin: _toToken!,
      );
      if (!mounted) return;
      _showConfirmSheet(quote);
    } on AuthException catch (_) {
      if (!mounted) return;
      await redirectToSignIn(context);
    } on CryptoException catch (e) {
      if (!mounted) return;
      setState(() => _submitError = e.message);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  void _showConfirmSheet(CryptoQuote quote) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SwapConfirmSheet(
        quote: quote,
        onDone: (result) {
          Navigator.pop(context); // close sheet
          _showSuccessDialog(result);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _showSuccessDialog(SwapOrderResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SwapSuccessDialog(
        fromSymbol: result.fromCoin,
        toSymbol: result.toCoin,
        fromAmount: result.coinAmount,
        toAmount: result.toCoinAmount,
        reference: result.reference,
        onDone: () {
          Navigator.pop(context); // close dialog
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const CryptoTransactionPendingScreen()),
          );
        },
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
          'Swap Crypto',
          style: TextStyle(
              color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh, color: _kGrey, size: 20),
              onPressed: _loadData,
              tooltip: 'Refresh rates',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : _loadError.isNotEmpty
              ? _ErrorRetry(message: _loadError, onRetry: _loadData)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final fromCoin = _coin(_fromToken);
    final toCoin = _coin(_toToken);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Swap From ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Swap From:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _kDark)),
                    if (_fromToken != null && _fromRate > 0)
                      Text('Rate: ${_fmtNgn(_fromRate)}/$_fromToken',
                          style:
                              const TextStyle(fontSize: 11, color: _kGrey)),
                  ],
                ),
                const SizedBox(height: 8),
                _TokenDropdown(
                  coin: fromCoin,
                  placeholder: 'Select Token',
                  onTap: _openFromSheet,
                ),
                const SizedBox(height: 12),

                // ── Amount input ─────────────────────────────────────────
                if (_fromToken != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d*')),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 14, color: _kDark),
                      decoration: InputDecoration(
                        hintText: 'Amount of $_fromToken to swap',
                        hintStyle: const TextStyle(
                            color: Color(0xFFB0B7C3), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // ── Swap icon ────────────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: (_fromToken != null || _toToken != null)
                        ? _swapTokens
                        : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.swap_vert,
                          color: _kDark, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Swap To ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Swap To:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _kDark)),
                    if (_toToken != null && _toRate > 0)
                      Text('Rate: ${_fmtNgn(_toRate)}/$_toToken',
                          style:
                              const TextStyle(fontSize: 11, color: _kGrey)),
                  ],
                ),
                const SizedBox(height: 8),
                _TokenDropdown(
                  coin: toCoin,
                  placeholder: 'Select Token',
                  onTap: _openToSheet,
                ),

                // ── Transaction Summary ───────────────────────────────────
                if (_fromToken != null &&
                    _toToken != null &&
                    _fromToken != _toToken) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Transaction Summary',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kDark),
                  ),
                  const SizedBox(height: 10),
                  _SummaryCard(
                    fromSymbol: _fromToken!,
                    toSymbol: _toToken!,
                    amount: _amount,
                    fromNgnValue: _fromNgnValue,
                    feeNgn: _feeNgn,
                    receiveAmount: _receiveAmount,
                  ),
                ],

                if (_submitError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_submitError,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),

        // ── Action Buttons ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _canSwap ? _onSwap : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    disabledBackgroundColor:
                        _kBlue.withValues(alpha: 0.45),
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
                          'Swap Token',
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

// ─── Error / Retry ────────────────────────────────────────────────────────────

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

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

// ─── Token Dropdown ───────────────────────────────────────────────────────────

class _TokenDropdown extends StatelessWidget {
  final CoinInfo? coin;
  final String placeholder;
  final VoidCallback onTap;

  const _TokenDropdown({
    required this.coin,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            if (coin != null) ...[
              _TokenIcon(coin: coin!, size: 28),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                coin?.symbol ?? placeholder,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      coin != null ? FontWeight.w600 : FontWeight.normal,
                  color: coin != null ? _kDark : _kGrey,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: _kGrey),
          ],
        ),
      ),
    );
  }
}

// ─── Token Icon ───────────────────────────────────────────────────────────────

class _TokenIcon extends StatelessWidget {
  final CoinInfo coin;
  final double size;

  const _TokenIcon({required this.coin, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return CoinLogo(
      logoUrl: coin.logoUrl,
      letter: coin.letter,
      letterColor: Colors.white,
      backgroundColor: coin.color,
      size: size,
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String fromSymbol;
  final String toSymbol;
  final double amount;
  final double fromNgnValue;
  final double feeNgn;
  final double receiveAmount;

  const _SummaryCard({
    required this.fromSymbol,
    required this.toSymbol,
    required this.amount,
    required this.fromNgnValue,
    required this.feeNgn,
    required this.receiveAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _SummaryRow(
              label: 'You send $fromSymbol:',
              value: _fmt(amount),
              isFirst: true),
          const Divider(height: 1, color: _kBorder),
          _SummaryRow(
              label: 'Value (NGN):',
              value: _fmtNgn(fromNgnValue)),
          const Divider(height: 1, color: _kBorder),
          _SummaryRow(
              label: 'Swap fee:',
              value: _fmtNgn(feeNgn)),
          const Divider(height: 1, color: _kBorder),
          _SummaryRow(
              label: 'You receive $toSymbol:',
              value: _fmt(receiveAmount),
              bold: true),
          const Divider(height: 1, color: _kBorder),
          const _SummaryRow(
              label: 'Est. processing time:',
              value: '24 hours',
              isLast: true),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        isFirst ? 14 : 12,
        16,
        isLast ? 14 : 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: _kGrey)),
          Text(
            value,
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.w600,
                color: _kDark),
          ),
        ],
      ),
    );
  }
}

// ─── Token Select Sheet ───────────────────────────────────────────────────────

class _TokenSelectSheet extends StatefulWidget {
  final String? excludeSymbol;
  final List<CoinInfo> coins;
  final ValueChanged<String> onSelect;

  const _TokenSelectSheet({
    required this.excludeSymbol,
    required this.coins,
    required this.onSelect,
  });

  @override
  State<_TokenSelectSheet> createState() => _TokenSelectSheetState();
}

class _TokenSelectSheetState extends State<_TokenSelectSheet> {
  String _query = '';

  List<CoinInfo> get _filtered {
    final q = _query.toLowerCase();
    return widget.coins
        .where((c) =>
            c.symbol != widget.excludeSymbol &&
            (q.isEmpty ||
                c.symbol.toLowerCase().contains(q) ||
                c.name.toLowerCase().contains(q)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.80;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Token',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _kDark)),
                      SizedBox(height: 3),
                      Text("Select the token you'd like to swap",
                          style:
                              TextStyle(fontSize: 13, color: _kGrey)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
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
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 14, color: _kDark),
                decoration: const InputDecoration(
                  hintText: 'Search token',
                  hintStyle: TextStyle(fontSize: 14, color: _kGrey),
                  prefixIcon: Icon(Icons.search, color: _kGrey, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final coin = _filtered[i];
                return InkWell(
                  onTap: () => widget.onSelect(coin.symbol),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        _TokenIcon(coin: coin, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(coin.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _kDark)),
                              Text(
                                coin.priceNgn > 0
                                    ? '${coin.symbol} · ${_fmtNgn(coin.priceNgn)}'
                                    : coin.symbol,
                                style: const TextStyle(
                                    fontSize: 12, color: _kGrey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Swap Confirm Sheet ───────────────────────────────────────────────────────

String _newIdempKey() {
  final r = Random.secure();
  return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
}

class _SwapConfirmSheet extends StatefulWidget {
  final CryptoQuote quote;
  final ValueChanged<SwapOrderResult> onDone;
  final VoidCallback onCancel;

  const _SwapConfirmSheet({
    required this.quote,
    required this.onDone,
    required this.onCancel,
  });

  @override
  State<_SwapConfirmSheet> createState() => _SwapConfirmSheetState();
}

class _SwapConfirmSheetState extends State<_SwapConfirmSheet> {
  bool _submitting = false;
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

  bool get _expired => _countdown <= 0;

  Future<void> _submit() async {
    if (_submitting || _expired) return;
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      final result = await CryptoService.createSwapOrder(
        quoteId: widget.quote.quoteId,
        idempotencyKey: _newIdempKey(),
      );
      if (!mounted) return;
      widget.onDone(result);
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
    final q = widget.quote;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Confirm Swap',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kDark)),
                ),
                GestureDetector(
                  onTap: widget.onCancel,
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
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Countdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _expired
                          ? Colors.red.withValues(alpha: 0.08)
                          : const Color(0xFFEBF2FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _expired
                            ? Colors.red.shade200
                            : _kBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _expired ? Icons.timer_off : Icons.timer,
                          size: 16,
                          color: _expired ? Colors.red : _kBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _expired
                              ? 'Quote expired — please go back and try again.'
                              : 'Rate locked for $_countdown seconds',
                          style: TextStyle(
                            fontSize: 12,
                            color: _expired ? Colors.red : _kBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SummaryRow(
                    label: 'You send ${q.coin}:',
                    value: _fmt(q.coinAmount),
                    isFirst: true,
                  ),
                  const Divider(height: 1, color: _kBorder),
                  _SummaryRow(
                    label: 'Rate:',
                    value: _fmtNgn(q.rateNgn),
                  ),
                  const Divider(height: 1, color: _kBorder),
                  _SummaryRow(
                    label: 'Swap fee:',
                    value: _fmtNgn(q.feeNgn),
                  ),
                  const Divider(height: 1, color: _kBorder),
                  _SummaryRow(
                    label: 'You receive ${q.toCoin}:',
                    value: _fmt(q.toCoinAmount),
                    bold: true,
                  ),
                  const Divider(height: 1, color: _kBorder),
                  _SummaryRow(
                    label: 'To rate:',
                    value: _fmtNgn(q.toRateNgn),
                    isLast: true,
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_error,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting || _expired ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  disabledBackgroundColor:
                      _kBlue.withValues(alpha: 0.45),
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
                    : const Text(
                        'Confirm Swap',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Swap Success Dialog ──────────────────────────────────────────────────────

class _SwapSuccessDialog extends StatelessWidget {
  final String fromSymbol;
  final String toSymbol;
  final double fromAmount;
  final double toAmount;
  final String reference;
  final VoidCallback onDone;

  const _SwapSuccessDialog({
    required this.fromSymbol,
    required this.toSymbol,
    required this.fromAmount,
    required this.toAmount,
    required this.reference,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kBlue, width: 3),
              ),
              child: const Icon(Icons.check, color: _kBlue, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'Swap Submitted!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kDark),
            ),
            const SizedBox(height: 10),
            Text(
              'Swapping ${_fmt(fromAmount)} $fromSymbol → ${_fmt(toAmount)} $toSymbol.\nYour order is being processed.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: _kGrey, height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Ref: $reference',
              style: const TextStyle(fontSize: 12, color: _kGrey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
      ),
    );
  }
}
