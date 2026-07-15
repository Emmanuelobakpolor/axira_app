import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart' show AuthService, kSessionExpiredError;

const _kBaseUrl = 'https://web-production-b557d.up.railway.app/api';

class GiftCardException implements Exception {
  final String message;
  GiftCardException(this.message);
  @override
  String toString() => message;
}

class GiftProduct {
  final int productId;
  final String productName;
  final double unitPriceUsd;
  final double unitPriceNgn;
  final bool openRange;
  final double? minUsd;
  final double? maxUsd;
  final String category;
  final String redeemInstruction;
  final double discountPercentage;
  final double senderFee;
  final double senderFeePercentage;

  const GiftProduct({
    required this.productId,
    required this.productName,
    required this.unitPriceUsd,
    required this.unitPriceNgn,
    this.openRange = false,
    this.minUsd,
    this.maxUsd,
    this.category = '',
    this.redeemInstruction = '',
    this.discountPercentage = 0,
    this.senderFee = 0,
    this.senderFeePercentage = 0,
  });

  String get displayLabel => openRange
      ? '\$${minUsd?.toStringAsFixed(0) ?? '?'}–\$${maxUsd?.toStringAsFixed(0) ?? '?'} ${productName.split(' ').last}'
      : '\$${unitPriceUsd.toStringAsFixed(0)} ${productName.split(' ').last}';

  factory GiftProduct.fromJson(Map<String, dynamic> j) {
    final isOpen = j['open_range'] == true;
    return GiftProduct(
      productId: j['product_id'] as int,
      productName: j['product_name'] as String,
      unitPriceUsd: isOpen ? 0 : double.parse(j['unit_price_usd'].toString()),
      unitPriceNgn: isOpen ? 0 : double.parse(j['unit_price_ngn'].toString()),
      openRange: isOpen,
      minUsd: isOpen ? double.tryParse(j['min_usd']?.toString() ?? '') : null,
      maxUsd: isOpen ? double.tryParse(j['max_usd']?.toString() ?? '') : null,
      category: j['category'] as String? ?? '',
      redeemInstruction: j['redeem_instruction'] as String? ?? '',
      discountPercentage: (j['discount_percentage'] as num?)?.toDouble() ?? 0,
      senderFee: (j['sender_fee'] as num?)?.toDouble() ?? 0,
      senderFeePercentage: (j['sender_fee_percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class GiftCardBuyResult {
  final String reference;
  final String productName;
  final double amountUsd;
  final double amountNgn;
  final String redeemCode;
  final String redeemPin;

  const GiftCardBuyResult({
    required this.reference,
    required this.productName,
    required this.amountUsd,
    required this.amountNgn,
    required this.redeemCode,
    required this.redeemPin,
  });

  factory GiftCardBuyResult.fromJson(Map<String, dynamic> j) => GiftCardBuyResult(
        reference: j['reference'] as String,
        productName: j['product_name'] as String,
        amountUsd: double.parse(j['amount_usd'].toString()),
        amountNgn: double.parse(j['amount_ngn'].toString()),
        redeemCode: j['redeem_code'] as String? ?? '',
        redeemPin: j['redeem_pin'] as String? ?? '',
      );
}

class GiftTradeItem {
  final String id;
  final String type; // 'buy' or 'sell'
  final String brand;
  final String brandAsset;
  final double amountUsd;
  final double amountNgn;
  final String status;
  final DateTime createdAt;
  final String? redeemCode;
  final String? redeemPin;
  final String? productName;

  const GiftTradeItem({
    required this.id,
    required this.type,
    required this.brand,
    required this.brandAsset,
    required this.amountUsd,
    required this.amountNgn,
    required this.status,
    required this.createdAt,
    this.redeemCode,
    this.redeemPin,
    this.productName,
  });

  factory GiftTradeItem.fromJson(Map<String, dynamic> j) => GiftTradeItem(
        id: j['id'] as String,
        type: j['type'] as String,
        brand: j['brand'] as String,
        brandAsset: j['brand_asset'] as String? ?? '',
        amountUsd: double.parse(j['amount_usd'].toString()),
        amountNgn: double.parse(j['amount_ngn'].toString()),
        status: j['status'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        redeemCode: j['redeem_code'] as String?,
        redeemPin: j['redeem_pin'] as String?,
        productName: j['product_name'] as String?,
      );
}

class GiftBrand {
  final int brandId;
  final String brandName;
  final String logoUrl;

  const GiftBrand({
    required this.brandId,
    required this.brandName,
    required this.logoUrl,
  });

  factory GiftBrand.fromJson(Map<String, dynamic> j) => GiftBrand(
        brandId: j['brand_id'] as int,
        brandName: j['brand_name'] as String,
        logoUrl: j['logo_url'] as String? ?? '',
      );
}

class GiftCardService {
  static String _extractError(http.Response res) {
    if (res.statusCode == 401) return kSessionExpiredError;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      // handle DRF validation errors (dict of field: [messages])
      for (final entry in body.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String) return v;
      }
    } catch (_) {}
    return 'Something went wrong. Please try again.';
  }

  static Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on GiftCardException {
      rethrow;
    } on SocketException {
      throw GiftCardException('Could not reach the server. Check your connection.');
    } catch (e) {
      throw GiftCardException('Unexpected error: $e');
    }
  }

  static Future<List<GiftBrand>> getBrands([String countryCode = 'US']) =>
      _guard(() async {
        final uri = Uri.parse('$_kBaseUrl/giftcards/brands/').replace(
          queryParameters: {'country_code': countryCode},
        );
        final res = await http.get(uri, headers: await AuthService.authHeaders());
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return (body['brands'] as List)
              .map((e) => GiftBrand.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw GiftCardException(_extractError(res));
      });

  static Future<double> getRate() => _guard(() async {
        final res = await http.get(
          Uri.parse('$_kBaseUrl/giftcards/rate/'),
          headers: await AuthService.authHeaders(),
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return double.parse(body['ngn_per_usd'].toString());
        }
        throw GiftCardException(_extractError(res));
      });

  static Future<List<GiftProduct>> getProducts(String brand, String countryCode) =>
      _guard(() async {
        final uri = Uri.parse('$_kBaseUrl/giftcards/products/').replace(
          queryParameters: {'brand': brand, 'country_code': countryCode},
        );
        final res = await http.get(uri, headers: await AuthService.authHeaders());
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return (body['products'] as List)
              .map((e) => GiftProduct.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw GiftCardException(_extractError(res));
      });

  static Future<GiftCardBuyResult> buyGiftCard({
    required int productId,
    required double unitPriceUsd,
    required String brand,
    required String brandAsset,
    required String countryCode,
    required String pin,
  }) =>
      _guard(() async {
        final res = await http.post(
          Uri.parse('$_kBaseUrl/giftcards/buy/'),
          headers: await AuthService.authHeaders(),
          body: jsonEncode({
            'product_id': productId,
            'unit_price_usd': unitPriceUsd.toStringAsFixed(2),
            'brand': brand,
            'brand_asset': brandAsset,
            'country_code': countryCode,
            'pin': pin,
          }),
        );
        if (res.statusCode == 201) {
          return GiftCardBuyResult.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>);
        }
        throw GiftCardException(_extractError(res));
      });

  static Future<String> submitSell({
    required String brand,
    required String brandAsset,
    required String country,
    required String cardType,
    required double amountUsd,
    required List<File> images,
  }) =>
      _guard(() async {
        final headers = await AuthService.authHeaders();
        // Remove Content-Type so http sets multipart boundary correctly
        headers.remove('Content-Type');

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_kBaseUrl/giftcards/sell/'),
        );
        request.headers.addAll(headers);
        request.fields['brand'] = brand;
        request.fields['brand_asset'] = brandAsset;
        request.fields['country'] = country;
        request.fields['card_type'] = cardType;
        request.fields['amount_usd'] = amountUsd.toStringAsFixed(2);

        for (final img in images) {
          request.files
              .add(await http.MultipartFile.fromPath('images', img.path));
        }

        final streamed = await request.send();
        final res = await http.Response.fromStream(streamed);
        if (res.statusCode == 201) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return body['reference'] as String;
        }
        throw GiftCardException(_extractError(res));
      });

  static Future<List<GiftTradeItem>> getHistory() => _guard(() async {
        final res = await http.get(
          Uri.parse('$_kBaseUrl/giftcards/history/'),
          headers: await AuthService.authHeaders(),
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return (body['items'] as List)
              .map((e) => GiftTradeItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw GiftCardException(_extractError(res));
      });
}
