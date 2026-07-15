import 'package:flutter/material.dart';

import '../../services/auth_service.dart' show kSessionExpiredError;
import '../../services/giftcard_service.dart';
import '../../utils/session_guard.dart';
import '../../widgets/brand_image.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);

class TradeHistoryScreen extends StatefulWidget {
  const TradeHistoryScreen({super.key});

  @override
  State<TradeHistoryScreen> createState() => _TradeHistoryScreenState();
}

class _TradeHistoryScreenState extends State<TradeHistoryScreen> {
  int _tab = 0;
  static const _tabs = ['All', 'Purchased', 'Sold'];

  List<GiftTradeItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await GiftCardService.getHistory();
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    } on GiftCardException catch (e) {
      if (!mounted) return;
      if (e.message == kSessionExpiredError) {
        await redirectToSignIn(context);
        return;
      }
      setState(() { _loading = false; _error = e.message; });
    }
  }

  List<GiftTradeItem> get _filtered {
    switch (_tab) {
      case 1:
        return _items.where((t) => t.type == 'buy').toList();
      case 2:
        return _items.where((t) => t.type == 'sell').toList();
      default:
        return _items;
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final trades = _filtered;

    // Group by date label
    final grouped = <String, List<GiftTradeItem>>{};
    for (final t in trades) {
      final key = _formatDate(t.createdAt.toLocal());
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final sortedDates = grouped.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back,
                color: Color(0xFF374151), size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Trade History',
            style: TextStyle(
                color: _kDark,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _kGrey),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final selected = _tab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: i < _tabs.length - 1 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? _kBlue
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _kGrey,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 8),

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
                                    backgroundColor: _kBlue,
                                    elevation: 0),
                                child: const Text('Retry',
                                    style:
                                        TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : trades.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 48, color: _kGrey),
                                SizedBox(height: 12),
                                Text('No transactions found',
                                    style: TextStyle(
                                        color: _kGrey, fontSize: 16)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: sortedDates.length,
                            itemBuilder: (context, index) {
                              final date = sortedDates[index];
                              final dayItems = grouped[date]!;
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Text(date,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _kGrey,
                                        )),
                                  ),
                                  ...dayItems
                                      .map((t) => _TradeItem(item: t)),
                                ],
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _TradeItem extends StatelessWidget {
  final GiftTradeItem item;
  const _TradeItem({required this.item});

  Color get _badgeBg {
    switch (item.status) {
      case 'pending':
        return const Color(0xFFFFF7E6);
      case 'completed':
      case 'approved':
        return const Color(0xFFE6F7EE);
      case 'failed':
      case 'declined':
        return const Color(0xFFFFE9E9);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color get _badgeText {
    switch (item.status) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'completed':
      case 'approved':
        return const Color(0xFF059669);
      case 'failed':
      case 'declined':
        return const Color(0xFFDC2626);
      default:
        return _kGrey;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case 'completed':
        return 'success';
      case 'approved':
        return 'approved';
      case 'failed':
      case 'declined':
        return 'decline';
      default:
        return item.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = item.type == 'buy';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Brand image or placeholder
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: BrandImage(item.brandAsset, height: 32, width: 32),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.brand,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kDark),
                ),
                const SizedBox(height: 2),
                Text(
                  isBuy ? 'Purchased' : 'Sold',
                  style: const TextStyle(fontSize: 12, color: _kGrey),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${item.amountUsd.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kDark),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _badgeText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
