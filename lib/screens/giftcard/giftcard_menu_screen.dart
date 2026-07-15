import 'package:flutter/material.dart';
import 'buy_giftcard_screen.dart';
import 'sell_giftcard_screen.dart';
import 'trade_history_screen.dart';

class GiftcardMenuScreen extends StatelessWidget {
  const GiftcardMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar('Gift Card', context),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          children: [
            _MenuItem(
              icon: Icons.card_giftcard_outlined,
              label: 'Buy Giftcard',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BuyGiftcardScreen()),
              ),
            ),
            _MenuItem(
              icon: Icons.sell_outlined,
              label: 'Sell Giftcard',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SellGiftcardScreen()),
              ),
            ),
            _MenuItem(
              icon: Icons.receipt_long_outlined,
              label: 'Transaction History',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TradeHistoryScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared AppBar ────────────────────────────────────────────────────────────

AppBar _appBar(String title, BuildContext context) {
  return AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
      onPressed: () => Navigator.maybePop(context),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

// ─── Menu item ────────────────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF374151)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF9CA3AF), size: 22),
          ],
        ),
      ),
    );
  }
}
