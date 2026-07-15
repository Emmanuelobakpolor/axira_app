import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart' show AuthService, kSessionExpiredError;

const _kBaseUrl = 'https://web-production-b557d.up.railway.app/api';

class WalletException implements Exception {
  final String message;
  WalletException(this.message);

  @override
  String toString() => message;
}

class WalletInfo {
  final double ngnBalance;

  WalletInfo({required this.ngnBalance});

  factory WalletInfo.fromJson(Map<String, dynamic> json) => WalletInfo(
        ngnBalance: double.parse(json['ngn_balance'] as String),
      );
}

class WalletTransaction {
  final String id;
  final String txType;
  final double amount;
  final String status;
  final String reference;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.txType,
    required this.amount,
    required this.status,
    required this.reference,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as String,
        txType: json['tx_type'] as String,
        amount: double.parse(json['amount'] as String),
        status: json['status'] as String,
        reference: json['reference'] as String,
        bankName: json['bank_name'] as String? ?? '',
        accountNumber: json['account_number'] as String? ?? '',
        accountName: json['account_name'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class NigerianBank {
  final String name;
  final String code;
  NigerianBank({required this.name, required this.code});
}

class WalletService {
  static String _extractError(http.Response res) {
    if (res.statusCode == 401) return kSessionExpiredError;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final err = body['error'];
      if (err is String) return err;
      for (final v in body.values) {
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String) return v;
      }
    } catch (_) {}
    return 'Something went wrong. Please try again.';
  }

  static Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on WalletException {
      rethrow;
    } on SocketException {
      throw WalletException('Could not reach the server. Check your connection.');
    } catch (e) {
      throw WalletException('Unexpected error: $e');
    }
  }

  // ── Balance ────────────────────────────────────────────────────────────────

  static Future<WalletInfo> getWallet() => _guard(() async {
        final res = await http.get(
          Uri.parse('$_kBaseUrl/wallet/balance/'),
          headers: await AuthService.authHeaders(),
        );
        if (res.statusCode == 200) {
          return WalletInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        }
        throw WalletException(_extractError(res));
      });

  // ── Deposit (Flutterwave) ──────────────────────────────────────────────────

  // Returns the Flutterwave public key provided by the backend.
  static Future<String> initiateDeposit(double amount, String txRef) =>
      _guard(() async {
        final res = await http.post(
          Uri.parse('$_kBaseUrl/wallet/initiate-deposit/'),
          headers: await AuthService.authHeaders(),
          body: jsonEncode({
            'amount': amount.toStringAsFixed(2),
            'tx_ref': txRef,
          }),
        );
        if (res.statusCode == 201) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return body['public_key'] as String;
        }
        throw WalletException(_extractError(res));
      });

  static Future<double> verifyPayment(String txRef) => _guard(() async {
        final res = await http.post(
          Uri.parse('$_kBaseUrl/wallet/verify-payment/'),
          headers: await AuthService.authHeaders(),
          body: jsonEncode({'tx_ref': txRef}),
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return double.parse(body['ngn_balance'].toString());
        }
        throw WalletException(_extractError(res));
      });

  // ── Banks & account resolution ─────────────────────────────────────────────

  static Future<List<NigerianBank>> getBanks() => _guard(() async {
        final res = await http.get(
          Uri.parse('$_kBaseUrl/wallet/banks/'),
          headers: await AuthService.authHeaders(),
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final list = body['banks'] as List<dynamic>;
          return list
              .map((b) => NigerianBank(
                    name: b['name'].toString(),
                    code: b['code'].toString(),
                  ))
              .toList();
        }
        throw WalletException(_extractError(res));
      });

  static Future<String> resolveAccount(
      String accountNumber, String bankCode) =>
      _guard(() async {
        final uri = Uri.parse('$_kBaseUrl/wallet/resolve-account/').replace(
          queryParameters: {
            'account_number': accountNumber,
            'bank_code': bankCode,
          },
        );
        final res = await http.get(uri, headers: await AuthService.authHeaders());
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return body['account_name'] as String;
        }
        throw WalletException(_extractError(res));
      });

  // ── Withdrawal ─────────────────────────────────────────────────────────────

  static Future<String> requestWithdrawal({
    required double amount,
    required String accountName,
    required String bankName,
    required String bankCode,
    required String accountNumber,
  }) =>
      _guard(() async {
        final res = await http.post(
          Uri.parse('$_kBaseUrl/wallet/withdraw/'),
          headers: await AuthService.authHeaders(),
          body: jsonEncode({
            'amount': amount.toStringAsFixed(2),
            'account_name': accountName,
            'bank_name': bankName,
            'bank_code': bankCode,
            'account_number': accountNumber,
          }),
        );
        if (res.statusCode == 201) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return body['reference'] as String;
        }
        throw WalletException(_extractError(res));
      });

  // ── Transaction history ────────────────────────────────────────────────────

  static Future<List<WalletTransaction>> getTransactions() =>
      _guard(() async {
        final res = await http.get(
          Uri.parse('$_kBaseUrl/wallet/transactions/'),
          headers: await AuthService.authHeaders(),
        );
        if (res.statusCode == 200) {
          final list = jsonDecode(res.body) as List;
          return list
              .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw WalletException(_extractError(res));
      });
}
