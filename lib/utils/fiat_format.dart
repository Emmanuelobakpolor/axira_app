import '../services/crypto_service.dart';

String _withCommas(String intPart) => intPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );

String formatNgn(double v) {
  final parts = v.toStringAsFixed(2).split('.');
  return '₦${_withCommas(parts[0])}.${parts[1]}';
}

String formatUsd(double v) {
  final parts = v.toStringAsFixed(2).split('.');
  return '\$${_withCommas(parts[0])}.${parts[1]}';
}

/// "≈ $12.50 · ₦20,000.00" for [qty] of [coin], or '' if no price is known.
String fiatValueLine(double qty, CoinInfo? coin) {
  if (coin == null || coin.priceNgn <= 0) return '';
  final ngn = formatNgn(qty * coin.priceNgn);
  if (coin.priceUsd <= 0) return '≈ $ngn';
  return '≈ ${formatUsd(qty * coin.priceUsd)} · $ngn';
}

/// Coin quantity with up to 8 decimals and no trailing zeros or exponent
/// notation, e.g. 0.00006188 → "0.00006188", 1.5 → "1.5".
String formatCoinQty(double qty) {
  var s = qty.toStringAsFixed(8);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// Floors [qty] to 8 decimals, so a USD → coin conversion never rounds
/// up past what the user typed (or holds).
double floorCoinQty(double qty) => (qty * 1e8).floorToDouble() / 1e8;
