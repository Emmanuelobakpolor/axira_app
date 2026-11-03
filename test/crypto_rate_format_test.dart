import 'package:axira/services/crypto_service.dart';
import 'package:axira/utils/fiat_format.dart';
import 'package:flutter_test/flutter_test.dart';

CryptoQuote _quote({
  required double coinAmount,
  required double rateNgn,
  required double totalNgn,
}) =>
    CryptoQuote(
      quoteId: 'q',
      type: 'sell',
      coin: 'BTC',
      toCoin: '',
      coinAmount: coinAmount,
      rateNgn: rateNgn,
      toRateNgn: 0,
      feeNgn: 0,
      totalNgn: totalNgn,
      toCoinAmount: 0,
      expiresAt: DateTime(2100),
      expiresIn: 30,
    );

void main() {
  group('formatUsdPrice', () {
    test('uses cents from a dollar up', () {
      expect(formatUsdPrice(76800.92), '\$76,800.92');
      expect(formatUsdPrice(1), '\$1.00');
    });

    test('keeps significant figures below a dollar', () {
      expect(formatUsdPrice(0.32209), '\$0.3221');
      expect(formatUsdPrice(0.00835), '\$0.00835');
      expect(formatUsdPrice(0.0000045511), '\$0.000004551');
    });

    test('never falls into exponent notation', () {
      expect(formatUsdPrice(1.2953e-9), '\$0.000000001295');
    });

    test('keeps at least two decimals', () {
      expect(formatUsdPrice(0.5), '\$0.50');
      expect(formatUsdPrice(0.1), '\$0.10');
    });
  });

  group('formatUsdRate', () {
    test('shows naira per dollar', () {
      expect(formatUsdRate(1376.4), '\$1 = ₦1,376.40');
    });

    test('shows a dash when unknown', () {
      expect(formatUsdRate(0), '—');
    });
  });

  group('CryptoQuote.effectiveUsdRate', () {
    test('equals the market rate with no fee', () {
      final q = _quote(coinAmount: 1, rateNgn: 100000, totalNgn: 100000);
      expect(q.effectiveUsdRate(1400), 1400);
    });

    test('drops by the fee on a sell', () {
      final q = _quote(coinAmount: 1, rateNgn: 100000, totalNgn: 98000);
      expect(q.effectiveUsdRate(1400), closeTo(1372, 0.001));
    });

    test('rises by the fee on a buy', () {
      final q = _quote(coinAmount: 1, rateNgn: 100000, totalNgn: 102000);
      expect(q.effectiveUsdRate(1400), closeTo(1428, 0.001));
    });
  });
}
