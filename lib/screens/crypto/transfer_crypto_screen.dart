import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart' show AuthException;
import '../../services/crypto_service.dart';
import '../../utils/session_guard.dart';
import '../../widgets/coin_logo.dart';
import 'transfer_success_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);
const _kDisabled = Color(0xFFBFD7FC);

String _newIdempKey() {
  final r = Random.secure();
  return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
}

String _qtyStr(double qty, String token) {
  final n = qty % 1 == 0 ? qty.toStringAsFixed(0) : qty.toString();
  return '$n $token';
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class TransferCryptoScreen extends StatefulWidget {
  const TransferCryptoScreen({super.key});

  @override
  State<TransferCryptoScreen> createState() => _TransferCryptoScreenState();
}

class _TransferCryptoScreenState extends State<TransferCryptoScreen> {
  bool _loading = true;
  String _loadError = '';
  List<CoinInfo> _coins = [];
  Map<String, double> _available = {};

  CoinInfo? _token;
  String _network = '';
  final _addressCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = '';
    });
    try {
      final results = await Future.wait([
        CryptoService.getPrices(),
        CryptoService.getWallets(),
      ]);
      if (!mounted) return;
      final pricesData = results[0] as CryptoPricesData;
      final wallets = results[1] as List<CryptoWalletBalance>;
      setState(() {
        _coins = pricesData.coins;
        _available = {for (final w in wallets) w.coin: w.available};
        _loading = false;
      });
    } on AuthException catch (_) {
      if (!mounted) return;
      await redirectToSignIn(context);
    } on CryptoException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;
  double get _availableForToken => _available[_token?.symbol] ?? 0;

  bool get _needsNetwork =>
      _token != null && kCryptoMultiChainNetworks.containsKey(_token!.symbol);

  bool get _canContinue =>
      _token != null &&
      (!_needsNetwork || _network.isNotEmpty) &&
      _addressCtrl.text.trim().isNotEmpty &&
      _qty > 0 &&
      _qty <= _availableForToken;

  void _openTokenSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        builder: (_, ctrl) => _TokenPickerSheet(
          coins: _coins,
          available: _available,
          selected: _token,
          scrollCtrl: ctrl,
          onSelect: (tok) {
            setState(() {
              _token = tok;
              _network = '';
            });
            Navigator.pop(context);
          },
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openChainSheet() {
    if (_token == null) return;
    final chains = kCryptoMultiChainNetworks[_token!.symbol] ?? const [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PickerSheet(
        title: 'Select Network',
        items: chains,
        selected: _network,
        onSelect: (v) => setState(() => _network = v),
      ),
    );
  }

  void _setMax() {
    setState(() => _qtyCtrl.text = _availableForToken == 0
        ? ''
        : _availableForToken.toString());
  }

  void _onContinue() {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _TransferSummaryDialog(
        coin: _token!,
        network: _network,
        address: _addressCtrl.text.trim(),
        qty: _qty,
        onSuccess: (result) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransferSuccessScreen(result: result),
            ),
          );
        },
        onCancel: () => Navigator.pop(context),
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
          'Transfer Crypto',
          style: TextStyle(
              color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : _loadError.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: _kGrey, fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _kBlue),
                          child: const Text('Retry',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Select Token ───────────────────────────────────────────
                GestureDetector(
                  onTap: _openTokenSheet,
                  child: _DropdownField(
                    hint: 'Select Token',
                    child: _token == null
                        ? null
                        : Row(
                            children: [
                              CoinLogo(
                                logoUrl: _token!.logoUrl,
                                letter: _token!.letter,
                                letterColor: _token!.color,
                                backgroundColor:
                                    _token!.color.withValues(alpha: 0.15),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(_token!.symbol,
                                  style: const TextStyle(
                                      fontSize: 14, color: _kDark)),
                            ],
                          ),
                  ),
                ),
                if (_token != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Available: ${_qtyStr(_availableForToken, _token!.symbol)}',
                    style: const TextStyle(fontSize: 12, color: _kGrey),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Select Network (only for multi-chain coins) ─────────
                if (_needsNetwork) ...[
                  GestureDetector(
                    onTap: _openChainSheet,
                    child: _DropdownField(
                      hint: 'Select Network',
                      child: _network.isEmpty
                          ? null
                          : Text(_network,
                              style: const TextStyle(
                                  fontSize: 14, color: _kDark)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Wallet Address ─────────────────────────────────────────
                _InputField(
                  controller: _addressCtrl,
                  hint: 'Enter receiving wallet address',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // ── Quantity ───────────────────────────────────────────────
                _InputField(
                  controller: _qtyCtrl,
                  hint: 'Enter quantity to transfer',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  suffix: TextButton(
                    onPressed: _token == null ? null : _setMax,
                    child: const Text('MAX',
                        style: TextStyle(
                            color: _kBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _qty > _availableForToken
                      ? 'Amount exceeds your available balance.'
                      : 'Min: 0.00',
                  style: TextStyle(
                    fontSize: 12,
                    color: _qty > _availableForToken ? Colors.red : _kBlue,
                  ),
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
                  onPressed: _canContinue ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    disabledBackgroundColor: _kBlue.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
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

// ─── Dropdown Field ───────────────────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  final String hint;
  final Widget? child;
  const _DropdownField({required this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: child ??
                Text(hint,
                    style: const TextStyle(fontSize: 14, color: _kGrey)),
          ),
          const Icon(Icons.keyboard_arrow_down, color: _kGrey),
        ],
      ),
    );
  }
}

// ─── Input Field ──────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  final Widget? suffix;
  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: _kDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
          border: InputBorder.none,
          suffixIcon: suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: suffix,
                ),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ─── Token Picker Sheet ───────────────────────────────────────────────────────

class _TokenPickerSheet extends StatefulWidget {
  final List<CoinInfo> coins;
  final Map<String, double> available;
  final CoinInfo? selected;
  final ScrollController scrollCtrl;
  final ValueChanged<CoinInfo> onSelect;
  final VoidCallback onClose;
  const _TokenPickerSheet({
    required this.coins,
    required this.available,
    required this.selected,
    required this.scrollCtrl,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_TokenPickerSheet> createState() => _TokenPickerSheetState();
}

class _TokenPickerSheetState extends State<_TokenPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.coins
        : widget.coins
            .where((t) =>
                t.symbol.toLowerCase().contains(q) ||
                t.name.toLowerCase().contains(q))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Select Token',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _kDark),
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
                  child: const Icon(Icons.close,
                      size: 16, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 14, color: _kDark),
            decoration: InputDecoration(
              hintText: 'Search token name',
              hintStyle:
                  const TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFFB0B7C3), size: 18),
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No coins match your search.',
                      style: TextStyle(fontSize: 13, color: _kGrey)),
                )
              : ListView.separated(
                  controller: widget.scrollCtrl,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  itemBuilder: (_, i) {
                    final tok = filtered[i];
                    final isSelected = widget.selected?.symbol == tok.symbol;
                    final avail = widget.available[tok.symbol] ?? 0;
                    return InkWell(
                      onTap: () => widget.onSelect(tok),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            CoinLogo(
                              logoUrl: tok.logoUrl,
                              letter: tok.letter,
                              letterColor: tok.color,
                              backgroundColor:
                                  tok.color.withValues(alpha: 0.15),
                              size: 36,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tok.symbol,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _kDark)),
                                  Text(tok.name,
                                      style: const TextStyle(
                                          fontSize: 12, color: _kGrey)),
                                ],
                              ),
                            ),
                            Text(_qtyStr(avail, tok.symbol),
                                style: const TextStyle(
                                    fontSize: 12, color: _kGrey)),
                            const SizedBox(width: 8),
                            if (isSelected)
                              const Icon(Icons.check,
                                  color: _kBlue, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Simple Picker Sheet (network) ─────────────────────────────────────────────

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _PickerSheet(
      {required this.title,
      required this.items,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _kDark),
          ),
        ),
        ...items.map(
          (item) => InkWell(
            onTap: () => onSelect(item),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(item,
                        style: const TextStyle(fontSize: 14, color: _kDark)),
                  ),
                  if (item == selected)
                    const Icon(Icons.check, color: _kBlue, size: 18),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Transfer Summary Dialog ──────────────────────────────────────────────────

class _TransferSummaryDialog extends StatefulWidget {
  final CoinInfo coin;
  final String network;
  final String address;
  final double qty;
  final ValueChanged<WithdrawalResult> onSuccess;
  final VoidCallback onCancel;

  const _TransferSummaryDialog({
    required this.coin,
    required this.network,
    required this.address,
    required this.qty,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<_TransferSummaryDialog> createState() =>
      _TransferSummaryDialogState();
}

class _TransferSummaryDialogState extends State<_TransferSummaryDialog> {
  bool _submitting = false;
  String _error = '';

  String get _shortAddr {
    final a = widget.address;
    if (a.length <= 14) return a;
    return '${a.substring(0, 8)}.......${a.substring(a.length - 5)}';
  }

  Future<void> _send() async {
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      final result = await CryptoService.createWithdrawal(
        coin: widget.coin.symbol,
        address: widget.address,
        amount: widget.qty,
        network: widget.network,
        idempotencyKey: _newIdempKey(),
      );
      if (!mounted) return;
      if (result.status == 'failed') {
        setState(() => _error = result.errorDetail?.isNotEmpty == true
            ? result.errorDetail!
            : 'Transfer failed. Please try again.');
        return;
      }
      widget.onSuccess(result);
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
    final amtStr = _qtyStr(widget.qty, widget.coin.symbol);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 56),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer Summary',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _kDark),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Please preview the details below for your transfer',
                        style: TextStyle(fontSize: 12, color: _kGrey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submitting ? null : widget.onCancel,
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
            const SizedBox(height: 16),

            // ── Detail rows ────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _SRow(label: 'Sending To:', value: _shortAddr),
                  const _SDivider(),
                  _SRow(label: 'Token', value: widget.coin.symbol),
                  const _SDivider(),
                  _SRow(
                      label: 'Network',
                      value:
                          widget.network.isEmpty ? 'Default' : widget.network),
                  const _SDivider(),
                  _SRow(label: 'Amount:', value: amtStr),
                ],
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),

            // ── Send button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  disabledBackgroundColor: _kBlue.withValues(alpha: 0.45),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text(
                        'Send Token',
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
                onPressed: _submitting ? null : widget.onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kDisabled,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Cancel Transfer',
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
    );
  }
}

class _SRow extends StatelessWidget {
  final String label;
  final String value;
  const _SRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _kGrey)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _kDark),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SDivider extends StatelessWidget {
  const _SDivider();
  @override
  Widget build(BuildContext context) => const Divider(
      height: 1, indent: 14, endIndent: 14, color: Color(0xFFE5E7EB));
}
