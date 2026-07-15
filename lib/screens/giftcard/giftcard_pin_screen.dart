import 'package:flutter/material.dart';

import '../../services/auth_service.dart' show kSessionExpiredError;
import '../../services/giftcard_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/session_guard.dart';
import '../../widgets/brand_image.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);

class GiftcardPinScreen extends StatefulWidget {
  final String brandName;
  final String brandAsset;
  final int productId;
  final double unitPriceUsd;
  final double amountNgn;
  final String countryCode;

  const GiftcardPinScreen({
    super.key,
    required this.brandName,
    required this.brandAsset,
    required this.productId,
    required this.unitPriceUsd,
    required this.amountNgn,
    required this.countryCode,
  });

  @override
  State<GiftcardPinScreen> createState() => _GiftcardPinScreenState();
}

class _GiftcardPinScreenState extends State<GiftcardPinScreen> {
  String _pin = '';
  bool _loading = false;
  String? _error;

  // Set after successful purchase
  GiftCardBuyResult? _result;

  double? _walletBalance;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final info = await WalletService.getWallet();
      if (mounted) setState(() => _walletBalance = info.ngnBalance);
    } catch (_) {}
  }

  void _onKey(String key) {
    if (_loading || _result != null) return;
    if (key == '⌫') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
    } else if (_pin.length < 4) {
      setState(() => _pin += key);
    }
  }

  Future<void> _onConfirm() async {
    if (_pin.length != 4 || _loading) return;

    setState(() { _loading = true; _error = null; });

    try {
      final result = await GiftCardService.buyGiftCard(
        productId: widget.productId,
        unitPriceUsd: widget.unitPriceUsd,
        brand: widget.brandName,
        brandAsset: widget.brandAsset,
        countryCode: widget.countryCode,
        pin: _pin,
      );
      if (!mounted) return;
      setState(() { _loading = false; _result = result; });
    } on GiftCardException catch (e) {
      if (!mounted) return;
      if (e.message == kSessionExpiredError) {
        await redirectToSignIn(context);
        return;
      }
      setState(() { _loading = false; _error = e.message; _pin = ''; });
    }
  }

  String _formatNgn(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '₦$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final success = _result != null;
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
          'Buy Gift Card',
          style: TextStyle(color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    children: [
                      // Brand card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            BrandImage(widget.brandAsset, height: 52),
                            const SizedBox(height: 8),
                            Text(widget.brandName,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: _kDark)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // PIN label
                      Text(
                        success ? 'Purchase Complete!' : 'Enter 4-digit PIN to confirm',
                        style: TextStyle(fontSize: 12, color: success ? _kDark : _kGrey),
                      ),
                      const SizedBox(height: 12),

                      // PIN boxes
                      if (!success)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (i) {
                            final filled = i < _pin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: filled ? _kBlue : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _error != null ? Colors.red : _kBlue,
                                  width: 1.5,
                                ),
                              ),
                            );
                          }),
                        ),

                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.red),
                            textAlign: TextAlign.center),
                      ],

                      const SizedBox(height: 24),

                      if (!success) ...[
                        Text(
                          '\$${widget.unitPriceUsd.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.bold, color: _kDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '≈ ${_formatNgn(widget.amountNgn)}',
                          style: const TextStyle(fontSize: 13, color: _kGrey),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 12),

                        _DetailRow(
                          label: 'Service provider',
                          child: Row(
                            children: [
                              BrandImage(widget.brandAsset,
                                  height: 20, width: 20),
                              const SizedBox(width: 6),
                              Text(widget.brandName,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _kDark)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          label: 'Amount',
                          child: Text('\$${widget.unitPriceUsd.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _kDark)),
                        ),
                        const SizedBox(height: 16),

                        // Wallet balance chip
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0E24A0), Color(0xFF60A5FA)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Wallet Balance',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.8))),
                              const SizedBox(height: 4),
                              Text(
                                _walletBalance == null
                                    ? '…'
                                    : _formatNgn(_walletBalance!),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: (_pin.length == 4 && !_loading) ? _onConfirm : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kBlue,
                              disabledBackgroundColor: const Color(0xFFBFD7FC),
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Text('Confirm Payment',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ] else ...[
                        // ── Success state ──────────────────────────────────
                        const SizedBox(height: 8),
                        const Text('Successful',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _kDark)),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kBlue.withValues(alpha: 0.1),
                          ),
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
                                color: Colors.white, size: 36),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 12),

                        _DetailRow(
                          label: 'Reference',
                          child: Text(_result!.reference,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _kDark)),
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          label: 'Amount Paid',
                          child: Text(_formatNgn(_result!.amountNgn),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _kDark)),
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          label: 'Product',
                          child: Text(_result!.productName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _kDark)),
                        ),

                        if (_result!.redeemCode.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFFE5E7EB)),
                          const SizedBox(height: 12),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Gift Card Details',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _kDark)),
                          ),
                          const SizedBox(height: 10),
                          _CodeBox(label: 'Card Number', value: _result!.redeemCode),
                          if (_result!.redeemPin.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _CodeBox(label: 'PIN', value: _result!.redeemPin),
                          ],
                        ],
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).popUntil((r) => r.isFirst),
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
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Numpad — hidden after success
              if (!success) _Numpad(onKey: _onKey),
            ],
          ),

          // Loading overlay
          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: _kBlue),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _kGrey)),
        child,
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String label;
  final String value;
  const _CodeBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD0D7F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: _kGrey)),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kDark,
                letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}

// ─── Numpad ───────────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onKey;

  const _Numpad({required this.onKey});

  static const _keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['+*#', '0', '⌫'],
  ];
  static const _letters = [
    ['', 'ABC', 'DEF'],
    ['GHI', 'JKL', 'MNO'],
    ['PQRS', 'TUV', 'WXYZ'],
    ['', '', ''],
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Column(
        children: List.generate(4, (row) {
          return Expanded(
            child: Row(
              children: List.generate(3, (col) {
                final key = _keys[row][col];
                final letters = _letters[row][col];
                return Expanded(
                  child: InkWell(
                    onTap: () => onKey(key),
                    child: Center(
                      child: key == '⌫'
                          ? const Icon(Icons.backspace_outlined,
                              size: 22, color: _kDark)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  key,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                    color: key == '+*#' ? _kGrey : _kDark,
                                  ),
                                ),
                                if (letters.isNotEmpty)
                                  Text(letters,
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: _kGrey,
                                          letterSpacing: 1.2)),
                              ],
                            ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
