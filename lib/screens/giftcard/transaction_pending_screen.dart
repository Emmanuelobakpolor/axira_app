import 'package:flutter/material.dart';

import 'trade_history_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);

class TransactionPendingScreen extends StatelessWidget {
  final String? reference;

  const TransactionPendingScreen({super.key, this.reference});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),

            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kBlue.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF0E24A0), Color(0xFF60A5FA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.hourglass_top_rounded,
                      color: Colors.white, size: 36),
                ),
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'Transaction Pending',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _kDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Text(
              'Your transaction is being processed. '
              'This usually takes a few minutes. '
              'You will be notified once it is confirmed.',
              style: const TextStyle(
                  fontSize: 14, color: _kGrey, height: 1.6),
              textAlign: TextAlign.center,
            ),

            if (reference != null) ...[
              const SizedBox(height: 16),
              Text(
                'Reference: $reference',
                style: const TextStyle(
                    fontSize: 12,
                    color: _kGrey,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Return back home',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TradeHistoryScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kBlue, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Trade History',
                  style: TextStyle(
                      color: _kBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
