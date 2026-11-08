import 'package:flutter/material.dart';

import '../../services/giftcard_service.dart';
import '../../widgets/brand_image.dart';
import 'sell_giftcard_form_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);

class SellGiftcardScreen extends StatefulWidget {
  const SellGiftcardScreen({super.key});

  @override
  State<SellGiftcardScreen> createState() => _SellGiftcardScreenState();
}

class _SellGiftcardScreenState extends State<SellGiftcardScreen> {
  String _searchQuery = '';

  // Only cards with an admin-set rate can be sold, so the brand list comes
  // from the rate table rather than the full Reloadly catalogue.
  Map<String, List<GiftSellRate>> _ratesByBrand = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rates = await GiftCardService.getSellRates();
      if (!mounted) return;
      final byBrand = <String, List<GiftSellRate>>{};
      for (final r in rates) {
        byBrand.putIfAbsent(r.brand, () => []).add(r);
      }
      setState(() {
        _ratesByBrand = byBrand;
        _loading = false;
      });
    } on GiftCardException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  List<String> get _filteredBrands {
    final brands = _ratesByBrand.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (_searchQuery.isEmpty) return brands;
    return brands
        .where((b) => b.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  String _logoFor(String brand) => _ratesByBrand[brand]!
      .map((r) => r.logoUrl)
      .firstWhere((url) => url.isNotEmpty, orElse: () => '');

  @override
  Widget build(BuildContext context) {
    final brands = _filteredBrands;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sell Gift Card',
          style: TextStyle(
              color: _kDark, fontSize: 25, fontWeight: FontWeight.w500),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 14, color: _kDark),
              decoration: InputDecoration(
                hintText: 'Search brands...',
                hintStyle:
                    const TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFFB0B7C3), size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'Available Cards',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151)),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kBlue))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  style: const TextStyle(color: _kGrey),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _load,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: _kBlue, elevation: 0),
                                child: const Text('Retry',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : brands.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _ratesByBrand.isEmpty
                                    ? "We're not buying any gift cards right "
                                        'now. Please check back soon.'
                                    : 'No brands found',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _kGrey),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.15,
                              ),
                              itemCount: brands.length,
                              itemBuilder: (context, i) {
                                final brand = brands[i];
                                final logo = _logoFor(brand);
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SellGiftcardFormScreen(
                                        brandName: brand,
                                        brandAsset: logo,
                                        rates: _ratesByBrand[brand]!,
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        BrandImage(logo, height: 52),
                                        const SizedBox(height: 10),
                                        Text(
                                          brand,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: _kDark),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
