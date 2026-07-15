import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

const _kBaseUrl = 'https://web-production-b557d.up.railway.app/api';

class CryptoException implements Exception {
  final String message;
  CryptoException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the backend rejects an order because the market price moved
/// more than 2.5% since the user saw the quote.
class PriceChangedException extends CryptoException {
  final double liveRate;
  PriceChangedException(this.liveRate)
      : super('Market price has changed. Please review the updated rate.');
}

// ── Data models ───────────────────────────────────────────────────────────────

class CoinInfo {
  final String symbol;
  final String name;
  final Color color;
  final String letter;
  final String? logoUrl;
  final double priceNgn;

  const CoinInfo({
    required this.symbol,
    required this.name,
    required this.color,
    required this.letter,
    required this.logoUrl,
    required this.priceNgn,
  });

  factory CoinInfo.fromJson(Map<String, dynamic> json) {
    final hex = (json['color'] as String? ?? '#888888').replaceFirst('#', '');
    final colorVal = int.tryParse('FF$hex', radix: 16) ?? 0xFF888888;
    return CoinInfo(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      color: Color(colorVal),
      letter: json['letter'] as String,
      logoUrl: json['logo_url'] as String?,
      priceNgn: double.tryParse(json['price_ngn'].toString()) ?? 0,
    );
  }
}

class CryptoPricesData {
  final List<CoinInfo> coins;
  final Map<String, double> prices;

  const CryptoPricesData({required this.coins, required this.prices});
}

class CryptoFees {
  final double flatUsd;
  final double percent;

  const CryptoFees({required this.flatUsd, required this.percent});

  factory CryptoFees.fromJson(Map<String, dynamic> json) => CryptoFees(
        flatUsd: double.tryParse(json['flat_usd'].toString()) ?? 0,
        percent: double.tryParse(json['percent'].toString()) ?? 0,
      );
}

class CryptoQuote {
  final String quoteId;
  final String type;
  final String coin;
  final String toCoin;
  final double coinAmount;
  final double rateNgn;
  final double toRateNgn;
  final double feeNgn;
  final double totalNgn;
  final double toCoinAmount;
  final DateTime expiresAt;
  final int expiresIn;

  const CryptoQuote({
    required this.quoteId,
    required this.type,
    required this.coin,
    required this.toCoin,
    required this.coinAmount,
    required this.rateNgn,
    required this.toRateNgn,
    required this.feeNgn,
    required this.totalNgn,
    required this.toCoinAmount,
    required this.expiresAt,
    required this.expiresIn,
  });

  factory CryptoQuote.fromJson(Map<String, dynamic> json) => CryptoQuote(
        quoteId: json['quote_id'] as String,
        type: json['type'] as String,
        coin: json['coin'] as String,
        toCoin: json['to_coin']?.toString() ?? '',
        coinAmount: double.tryParse(json['coin_amount'].toString()) ?? 0,
        rateNgn: double.tryParse(json['rate_ngn'].toString()) ?? 0,
        toRateNgn: double.tryParse(json['to_rate_ngn']?.toString() ?? '0') ?? 0,
        feeNgn: double.tryParse(json['fee_ngn'].toString()) ?? 0,
        totalNgn: double.tryParse(json['total_ngn'].toString()) ?? 0,
        toCoinAmount:
            double.tryParse(json['to_coin_amount']?.toString() ?? '0') ?? 0,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 60,
      );

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class CryptoWalletBalance {
  final String coin;
  final double available;
  final double reserved;
  final double total;

  const CryptoWalletBalance({
    required this.coin,
    required this.available,
    required this.reserved,
    required this.total,
  });

  factory CryptoWalletBalance.fromJson(Map<String, dynamic> json) =>
      CryptoWalletBalance(
        coin: json['coin'] as String,
        available: double.tryParse(json['available'].toString()) ?? 0,
        reserved: double.tryParse(json['reserved'].toString()) ?? 0,
        total: double.tryParse(json['total'].toString()) ?? 0,
      );
}

class BankDetails {
  final String bankName;
  final String accountNumber;
  final String accountName;

  const BankDetails({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  factory BankDetails.fromJson(Map<String, dynamic> json) => BankDetails(
        bankName: json['bank_name']?.toString() ?? '',
        accountNumber: json['account_number']?.toString() ?? '',
        accountName: json['account_name']?.toString() ?? '',
      );
}

class FlutterwaveChargeInfo {
  final String publicKey;
  final String txRef;
  final double amount;
  final String customerEmail;
  final String customerPhone;
  final String customerName;

  const FlutterwaveChargeInfo({
    required this.publicKey,
    required this.txRef,
    required this.amount,
    required this.customerEmail,
    required this.customerPhone,
    required this.customerName,
  });

  factory FlutterwaveChargeInfo.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? {};
    return FlutterwaveChargeInfo(
      publicKey: json['public_key']?.toString() ?? '',
      txRef: json['tx_ref']?.toString() ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      customerEmail: customer['email']?.toString() ?? '',
      customerPhone: customer['phone']?.toString() ?? '',
      customerName: customer['name']?.toString() ?? '',
    );
  }
}

class BuyOrderResult {
  final String reference;
  final String coin;
  final double coinAmount;
  final double rateNgn;
  final double feeNgn;
  final double totalNgn;
  final bool needsPayment;
  final FlutterwaveChargeInfo? flutterwave;
  final BankDetails? bankDetails;
  final String status;
  final String? errorDetail;
  final bool refunded;

  const BuyOrderResult({
    required this.reference,
    required this.coin,
    required this.coinAmount,
    required this.rateNgn,
    required this.feeNgn,
    required this.totalNgn,
    required this.needsPayment,
    required this.flutterwave,
    required this.bankDetails,
    required this.status,
    this.errorDetail,
    this.refunded = false,
  });

  factory BuyOrderResult.fromJson(Map<String, dynamic> json) => BuyOrderResult(
        reference: json['reference'] as String,
        coin: json['coin'] as String,
        coinAmount: double.tryParse(json['coin_amount'].toString()) ?? 0,
        rateNgn: double.tryParse(json['rate_ngn'].toString()) ?? 0,
        feeNgn: double.tryParse(json['fee_ngn'].toString()) ?? 0,
        totalNgn: double.tryParse(json['total_ngn'].toString()) ?? 0,
        needsPayment: json['needs_payment'] as bool? ?? false,
        flutterwave: json['flutterwave'] != null
            ? FlutterwaveChargeInfo.fromJson(
                json['flutterwave'] as Map<String, dynamic>)
            : null,
        errorDetail: json['error_detail']?.toString(),
        refunded: json['refunded'] as bool? ?? false,
        bankDetails: json['bank_details'] != null
            ? BankDetails.fromJson(json['bank_details'] as Map<String, dynamic>)
            : null,
        status: json['status'] as String,
      );
}

class SellOrderResult {
  final String reference;
  final String coin;
  final double coinAmount;
  final double rateNgn;
  final double feeNgn;
  final double payoutNgn;
  final String depositAddress;
  final String status;

  const SellOrderResult({
    required this.reference,
    required this.coin,
    required this.coinAmount,
    required this.rateNgn,
    required this.feeNgn,
    required this.payoutNgn,
    required this.depositAddress,
    required this.status,
  });

  factory SellOrderResult.fromJson(Map<String, dynamic> json) =>
      SellOrderResult(
        reference: json['reference'] as String,
        coin: json['coin'] as String,
        coinAmount: double.tryParse(json['coin_amount'].toString()) ?? 0,
        rateNgn: double.tryParse(json['rate_ngn'].toString()) ?? 0,
        feeNgn: double.tryParse(json['fee_ngn'].toString()) ?? 0,
        payoutNgn: double.tryParse(json['payout_ngn'].toString()) ?? 0,
        depositAddress: json['deposit_address']?.toString() ?? '',
        status: json['status'] as String,
      );
}

class SwapOrderResult {
  final String reference;
  final String fromCoin;
  final String toCoin;
  final double coinAmount;
  final double toCoinAmount;
  final double feeNgn;
  final String status;

  const SwapOrderResult({
    required this.reference,
    required this.fromCoin,
    required this.toCoin,
    required this.coinAmount,
    required this.toCoinAmount,
    required this.feeNgn,
    required this.status,
  });

  factory SwapOrderResult.fromJson(Map<String, dynamic> json) =>
      SwapOrderResult(
        reference: json['reference'] as String,
        fromCoin: json['from_coin'] as String,
        toCoin: json['to_coin'] as String,
        coinAmount: double.tryParse(json['coin_amount'].toString()) ?? 0,
        toCoinAmount: double.tryParse(json['to_coin_amount'].toString()) ?? 0,
        feeNgn: double.tryParse(json['fee_ngn'].toString()) ?? 0,
        status: json['status'] as String,
      );
}

class CryptoOrderHistory {
  final String reference;
  final String orderType;
  final String coin;
  final String toCoin;
  final double coinAmount;
  final double toCoinAmount;
  final double rateNgn;
  final double feeNgn;
  final double totalNgn;
  final String status;
  final String createdAt;

  const CryptoOrderHistory({
    required this.reference,
    required this.orderType,
    required this.coin,
    required this.toCoin,
    required this.coinAmount,
    required this.toCoinAmount,
    required this.rateNgn,
    required this.feeNgn,
    required this.totalNgn,
    required this.status,
    required this.createdAt,
  });

  factory CryptoOrderHistory.fromJson(Map<String, dynamic> json) =>
      CryptoOrderHistory(
        reference: json['reference'] as String,
        orderType: json['order_type'] as String,
        coin: json['coin'] as String,
        toCoin: json['to_coin']?.toString() ?? '',
        coinAmount: double.tryParse(json['coin_amount'].toString()) ?? 0,
        toCoinAmount: double.tryParse(json['to_coin_amount'].toString()) ?? 0,
        rateNgn: double.tryParse(json['rate_ngn'].toString()) ?? 0,
        feeNgn: double.tryParse(json['fee_ngn'].toString()) ?? 0,
        totalNgn: double.tryParse(json['total_ngn'].toString()) ?? 0,
        status: json['status'] as String,
        createdAt: json['created_at'] as String,
      );
}

class WithdrawalResult {
  final String reference;
  final String coin;
  final String network;
  final String address;
  final double amount;
  final double fee;
  final String status;
  final String txId;
  final String createdAt;
  final String? errorDetail;

  const WithdrawalResult({
    required this.reference,
    required this.coin,
    required this.network,
    required this.address,
    required this.amount,
    required this.fee,
    required this.status,
    required this.txId,
    required this.createdAt,
    this.errorDetail,
  });

  factory WithdrawalResult.fromJson(Map<String, dynamic> json) =>
      WithdrawalResult(
        reference: json['reference'] as String,
        coin: json['coin'] as String,
        network: json['network']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        amount: double.tryParse(json['amount'].toString()) ?? 0,
        fee: double.tryParse(json['fee']?.toString() ?? '0') ?? 0,
        status: json['status'] as String,
        txId: json['tx_id']?.toString() ?? '',
        createdAt: json['created_at']?.toString() ?? '',
        errorDetail: json['error_detail']?.toString(),
      );
}

// Coins that run on more than one chain — everything else uses Quidax's
// default network for that coin, so no network picker is shown for them.
const Map<String, List<String>> kCryptoMultiChainNetworks = {
  'USDT': ['TRC20', 'ERC20', 'BEP20', 'SOL'],
  'USDC': ['ERC20', 'BEP20', 'SOL'],
};

// ── Service ───────────────────────────────────────────────────────────────────

class CryptoService {
  static String _extractError(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final err = body['error'] ?? body['detail'];
      if (err is String) return err;
    } catch (_) {}
    return 'Something went wrong. Please try again.';
  }

  static Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on CryptoException {
      rethrow;
    } on AuthException {
      rethrow;
    } on SocketException {
      throw CryptoException('Could not reach the server. Check your connection.');
    } catch (e) {
      throw CryptoException('Unexpected error: $e');
    }
  }

  // GET with auto token-refresh on 401.
  static Future<http.Response> _authedGet(String url) async {
    var headers = await AuthService.authHeaders();
    var res = await http.get(Uri.parse(url), headers: headers);
    if (res.statusCode == 401) {
      await AuthService.refreshAccessToken();
      headers = await AuthService.authHeaders();
      res = await http.get(Uri.parse(url), headers: headers);
    }
    return res;
  }

  // POST with auto token-refresh on 401.
  static Future<http.Response> _authedPost(
      String url, Map<String, dynamic> body) async {
    var headers = await AuthService.authHeaders();
    var res = await http.post(Uri.parse(url),
        headers: headers, body: jsonEncode(body));
    if (res.statusCode == 401) {
      await AuthService.refreshAccessToken();
      headers = await AuthService.authHeaders();
      res = await http.post(Uri.parse(url),
          headers: headers, body: jsonEncode(body));
    }
    return res;
  }

  /// Returns live prices + coin metadata. No auth required.
  static Future<CryptoPricesData> getPrices() => _guard(() async {
        final res = await http.get(
          Uri.parse('$_kBaseUrl/crypto/prices/'),
          headers: const {'Content-Type': 'application/json'},
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final rawPrices = body['prices'] as Map<String, dynamic>;
          final rawCoins = body['coins'] as List<dynamic>? ?? [];
          final prices = rawPrices
              .map((k, v) => MapEntry(k, double.tryParse(v.toString()) ?? 0));
          final coins = rawCoins
              .map((e) => CoinInfo.fromJson(e as Map<String, dynamic>))
              .toList();
          return CryptoPricesData(coins: coins, prices: prices);
        }
        throw CryptoException(_extractError(res));
      });

  /// Returns fee config. No auth required.
  static Future<Map<String, CryptoFees>> getFees() => _guard(() async {
        final res = await http.get(
          Uri.parse('$_kBaseUrl/crypto/fees/'),
          headers: const {'Content-Type': 'application/json'},
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final raw = body['fees'] as Map<String, dynamic>;
          return raw.map(
            (k, v) =>
                MapEntry(k, CryptoFees.fromJson(v as Map<String, dynamic>)),
          );
        }
        throw CryptoException(_extractError(res));
      });

  /// Request a price-locked quote valid for 60 seconds.
  /// Must call this before placing any buy/sell/swap order.
  /// [type] : 'buy' | 'sell' | 'swap'
  /// [toCoin] : required when type == 'swap'
  static Future<CryptoQuote> createQuote({
    required String type,
    required String coin,
    required double amount,
    String toCoin = '',
  }) =>
      _guard(() async {
        final body = <String, dynamic>{
          'type': type,
          'coin': coin,
          'amount': amount.toString(),
          if (toCoin.isNotEmpty) 'to_coin': toCoin,
        };
        final res = await _authedPost('$_kBaseUrl/crypto/quote/', body);
        if (res.statusCode == 201) {
          return CryptoQuote.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>);
        }
        throw CryptoException(_extractError(res));
      });

  /// Returns the user's internal wallet balances.
  static Future<List<CryptoWalletBalance>> getWallets() => _guard(() async {
        final res = await _authedGet('$_kBaseUrl/crypto/wallets/');
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final list = body['wallets'] as List<dynamic>;
          return list
              .map((e) =>
                  CryptoWalletBalance.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw CryptoException(_extractError(res));
      });

  /// Returns the user's deposit address for [coin].
  /// Pass [network] for multi-network coins (e.g. 'TRC20' for USDT).
  static Future<String> getDepositAddress(String coin,
          {String network = ''}) =>
      _guard(() async {
        var url = '$_kBaseUrl/crypto/address/$coin/';
        if (network.isNotEmpty) url += '?network=$network';
        final res = await _authedGet(url);
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return body['address']?.toString() ?? '';
        }
        throw CryptoException(_extractError(res));
      });

  /// Send crypto to an external address. Executes immediately — there's no
  /// confirmation step, so validate the coin/network/address/amount client-side
  /// before calling this.
  /// [network] only matters for multi-chain coins (e.g. 'TRC20' for USDT).
  static Future<WithdrawalResult> createWithdrawal({
    required String coin,
    required String address,
    required double amount,
    String network = '',
    String idempotencyKey = '',
  }) =>
      _guard(() async {
        final body = <String, dynamic>{
          'coin': coin,
          'address': address,
          'amount': amount.toString(),
          if (network.isNotEmpty) 'network': network,
          if (idempotencyKey.isNotEmpty) 'idempotency_key': idempotencyKey,
        };
        final res = await _authedPost('$_kBaseUrl/crypto/withdraw/', body);
        if (res.statusCode == 200 || res.statusCode == 201) {
          return WithdrawalResult.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>);
        }
        throw CryptoException(_extractError(res));
      });

  /// Fetch the current user's crypto withdrawal history.
  static Future<List<WithdrawalResult>> getWithdrawals() => _guard(() async {
        final res = await _authedGet('$_kBaseUrl/crypto/withdrawals/');
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final list = body['withdrawals'] as List<dynamic>;
          return list
              .map((e) => WithdrawalResult.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw CryptoException(_extractError(res));
      });

  /// Place a buy order using a confirmed quote.
  /// [idempotencyKey] prevents duplicate orders on network retries.
  static Future<BuyOrderResult> createBuyOrder({
    required String quoteId,
    String idempotencyKey = '',
  }) =>
      _guard(() async {
        final body = <String, dynamic>{
          'quote_id': quoteId,
          if (idempotencyKey.isNotEmpty) 'idempotency_key': idempotencyKey,
        };
        final res = await _authedPost('$_kBaseUrl/crypto/orders/buy/', body);
        if (res.statusCode == 200 || res.statusCode == 201) {
          return BuyOrderResult.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>);
        }
        throw CryptoException(_extractError(res));
      });

  /// Confirm a Flutterwave in-app charge for a buy order. Call this right
  /// after flutterwave_standard's SDK reports a successful charge — the
  /// backend re-verifies with Flutterwave server-side before executing the
  /// buy, so nothing is credited until this returns a completed status.
  static Future<BuyOrderResult> verifyBuyPayment(String reference) =>
      _guard(() async {
        final res = await _authedPost(
          '$_kBaseUrl/crypto/orders/buy/verify/',
          {'reference': reference},
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          return BuyOrderResult.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>);
        }
        throw CryptoException(_extractError(res));
      });

  /// Place a sell order using a confirmed quote.
  static Future<SellOrderResult> createSellOrder({
    required String quoteId,
    String idempotencyKey = '',
  }) =>
      _guard(() async {
        final body = <String, dynamic>{
          'quote_id': quoteId,
          if (idempotencyKey.isNotEmpty) 'idempotency_key': idempotencyKey,
        };
        final res = await _authedPost('$_kBaseUrl/crypto/orders/sell/', body);
        if (res.statusCode == 200 || res.statusCode == 201) {
          return SellOrderResult.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>);
        }
        throw CryptoException(_extractError(res));
      });

  /// Execute a swap order using a confirmed quote.
  static Future<SwapOrderResult> createSwapOrder({
    required String quoteId,
    String idempotencyKey = '',
  }) =>
      _guard(() async {
        final body = <String, dynamic>{
          'quote_id': quoteId,
          if (idempotencyKey.isNotEmpty) 'idempotency_key': idempotencyKey,
        };
        final res = await _authedPost('$_kBaseUrl/crypto/orders/swap/', body);
        if (res.statusCode == 200 || res.statusCode == 201) {
          return SwapOrderResult.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>);
        }
        throw CryptoException(_extractError(res));
      });

  /// Upload payment proof image for a buy order.
  static Future<void> uploadProof({
    required String reference,
    required File proof,
  }) =>
      _guard(() async {
        final authHeaders = await AuthService.authHeaders();
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_kBaseUrl/crypto/orders/$reference/proof/'),
        );
        request.headers['Authorization'] = authHeaders['Authorization']!;
        request.files
            .add(await http.MultipartFile.fromPath('proof', proof.path));

        final streamed = await request.send();
        final res = await http.Response.fromStream(streamed);

        if (res.statusCode == 200) return;
        throw CryptoException(_extractError(res));
      });

  /// Fetch the current user's crypto order history.
  static Future<List<CryptoOrderHistory>> getOrders() => _guard(() async {
        final res = await _authedGet('$_kBaseUrl/crypto/orders/');
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final list = body['orders'] as List<dynamic>;
          return list
              .map((e) =>
                  CryptoOrderHistory.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw CryptoException(_extractError(res));
      });
}
