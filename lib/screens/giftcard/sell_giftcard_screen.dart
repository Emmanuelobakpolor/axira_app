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
  String _countryCode = 'US';

  List<GiftBrand> _brands = [];
  bool _loading = true;
  String? _error;

  static const _countries = [
    ('United States', 'assets/USA.png', 'US'),
    ('Canada', 'assets/CANADA.png', 'CA'),
  ];

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
      final brands = await GiftCardService.getBrands(_countryCode);
      if (!mounted) return;
      setState(() {
        _brands = brands;
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

  List<GiftBrand> get _filtered {
    if (_searchQuery.isEmpty) return _brands;
    return _brands
        .where((b) =>
            b.brandName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _showCountrySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Select Country',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kDark)),
          ),
          ..._countries.map((c) => InkWell(
                onTap: () {
                  Navigator.pop(context);
                  if (c.$3 != _countryCode) {
                    setState(() => _countryCode = c.$3);
                    _load();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Image.asset(c.$2,
                          width: 28, height: 28, fit: BoxFit.cover),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(c.$1,
                            style: const TextStyle(
                                fontSize: 14, color: _kDark)),
                      ),
                      if (c.$3 == _countryCode)
                        const Icon(Icons.check, color: _kBlue, size: 18),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brands = _filtered;

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
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showCountrySheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_countryCode,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _kDark)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down,
                            size: 16, color: _kGrey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style:
                        const TextStyle(fontSize: 14, color: _kDark),
                    decoration: InputDecoration(
                      hintText: 'Search brands...',
                      hintStyle: const TextStyle(
                          color: Color(0xFFB0B7C3), fontSize: 14),
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xFFB0B7C3), size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
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
                                  style:
                                      const TextStyle(color: _kGrey),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _load,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: _kBlue,
                                    elevation: 0),
                                child: const Text('Retry',
                                    style: TextStyle(
                                        color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : brands.isEmpty
                        ? const Center(
                            child: Text('No brands found',
                                style: TextStyle(color: _kGrey)),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 16),
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
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SellGiftcardFormScreen(
                                      brandName: brand.brandName,
                                      brandAsset: brand.logoUrl,
                                    ),
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      BrandImage(brand.logoUrl,
                                          height: 52),
                                      const SizedBox(height: 10),
                                      Text(
                                        brand.brandName,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w500,
                                            color: _kDark),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
