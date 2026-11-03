import 'dart:math';

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

/// USD price per coin. Sub-dollar coins keep 4 significant figures so they
/// don't round to $0.00, e.g. 0.00835 → "$0.00835", 76800.92 → "$76,800.92".
String formatUsdPrice(double v) {
  if (v >= 1 || v <= 0) return formatUsd(v);
  final decimals = ((-log(v) / ln10).ceil() + 3).clamp(2, 20);
  final s = v
      .toStringAsFixed(decimals)
      .replaceFirst(RegExp(r'(?<=\.\d\d\d*?)0+$'), '');
  return '\$$s';
}

/// "$1 = ₦1,376.40" for a naira-per-dollar rate, or '—' if it isn't known.
String formatUsdRate(double ngnPerUsd) =>
    ngnPerUsd > 0 ? '\$1 = ${formatNgn(ngnPerUsd)}' : '—';

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
