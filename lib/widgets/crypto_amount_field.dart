import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/fiat_format.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);

/// Holds a crypto amount the user can type either in the coin itself or in
/// USD. [coinQty] is always the coin amount to send to the backend.
class CryptoAmountController extends ChangeNotifier {
  final text = TextEditingController();
  bool _inUsd = false;
  double _priceUsd = 0;

  bool get inUsd => _inUsd;
  double get priceUsd => _priceUsd;
  bool get canUseUsd => _priceUsd > 0;

  double get _entered => double.tryParse(text.text) ?? 0;

  double get coinQty {
    if (!_inUsd) return _entered;
    return _priceUsd > 0 ? floorCoinQty(_entered / _priceUsd) : 0;
  }

  double get usdValue => _inUsd ? _entered : _entered * _priceUsd;

  /// Updates the price used for conversion, e.g. when the coin changes.
  /// Falls back to coin entry if the new coin has no USD price.
  set priceUsd(double v) {
    _priceUsd = v;
    if (v <= 0 && _inUsd) {
      _inUsd = false;
      text.clear();
    }
    notifyListeners();
  }

  void toggleUnit() {
    if (!canUseUsd) return;
    final entered = _entered;
    if (entered > 0) {
      text.text = _inUsd
          ? formatCoinQty(floorCoinQty(entered / _priceUsd))
          : (entered * _priceUsd).toStringAsFixed(2);
    }
    _inUsd = !_inUsd;
    notifyListeners();
  }

  /// Sets an exact coin amount (e.g. MAX). Switches to coin entry so the
  /// value isn't rounded through USD and pushed past the balance.
  void setCoin(double qty) {
    _inUsd = false;
    text.text = qty > 0 ? formatCoinQty(qty) : '';
    notifyListeners();
  }

  void changed() => notifyListeners();

  /// "≈ 0.00617 BTC" while typing in USD, "≈ $500.00" while typing in coin.
  String conversionLine(String symbol) {
    if (_entered <= 0 || _priceUsd <= 0) return '';
    return _inUsd
        ? '≈ ${formatCoinQty(coinQty)} $symbol'
        : '≈ ${formatUsd(usdValue)}';
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}

/// Bordered amount input with a coin/USD switch, matching the crypto
/// screens' input style.
class CryptoAmountField extends StatelessWidget {
  final CryptoAmountController controller;
  final String symbol;
  final String hint;
  final Widget? trailing;

  const CryptoAmountField({
    super.key,
    required this.controller,
    required this.symbol,
    required this.hint,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final usd = controller.inUsd;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              if (usd)
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text('\$',
                      style: TextStyle(
                          fontSize: 14,
                          color: _kDark,
                          fontWeight: FontWeight.w600)),
                ),
              Expanded(
                child: TextField(
                  controller: controller.text,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(usd
                        ? RegExp(r'^\d*\.?\d{0,2}')
                        : RegExp(r'^\d*\.?\d{0,8}')),
                  ],
                  onChanged: (_) => controller.changed(),
                  style: const TextStyle(fontSize: 14, color: _kDark),
                  decoration: InputDecoration(
                    hintText: usd ? 'Enter amount in USD' : hint,
                    hintStyle:
                        const TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(usd ? 4 : 16, 16, 8, 16),
                  ),
                ),
              ),
              if (controller.canUseUsd && symbol.isNotEmpty)
                _UnitSwitch(
                  symbol: symbol,
                  inUsd: usd,
                  onToggle: controller.toggleUnit,
                ),
              if (trailing != null) trailing! else const SizedBox(width: 12),
            ],
          ),
        );
      },
    );
  }
}

class _UnitSwitch extends StatelessWidget {
  final String symbol;
  final bool inUsd;
  final VoidCallback onToggle;

  const _UnitSwitch(
      {required this.symbol, required this.inUsd, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool active) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _kBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : _kGrey)),
        );

    return Semantics(
      button: true,
      label: inUsd ? 'Enter amount in $symbol' : 'Enter amount in USD',
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [seg(symbol, !inUsd), seg('USD', inUsd)],
          ),
        ),
      ),
    );
  }
}
