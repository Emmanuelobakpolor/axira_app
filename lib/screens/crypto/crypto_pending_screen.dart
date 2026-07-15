import 'package:flutter/material.dart';

const _kBlue = Color(0xFF0E24A0);const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);

// ─── Transaction Pending Screen ───────────────────────────────────────────────
//
// Shown only for orders that are genuinely still in flight (e.g. a Quidax
// order that hasn't filled yet, or a manual bank-transfer awaiting admin
// confirmation). It must never assume success on its own — the caller is
// responsible for deciding the order is actually done (via a verified
// backend response) before showing any success state.

class CryptoTransactionPendingScreen extends StatelessWidget {
  const CryptoTransactionPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crypto',
          style: TextStyle(
              color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Hourglass icon ─────────────────────────────────────────
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
                            colors: [
                              Color(0xFF0E24A0),
                              Color(0xFF60A5FA),
                            ],
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

                  // ── Title ──────────────────────────────────────────────────
                  const Text(
                    'Transaction Pending',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _kDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // ── Subtitle ───────────────────────────────────────────────
                  const Text(
                    'Please wait while your token confirmation is being completed.',
                    style: TextStyle(
                        fontSize: 14, color: _kGrey, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // ── Info box ───────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF4FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFD7FC)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            size: 18, color: _kBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You can proceed to do other things while we confirm '
                            'your payment. Your token will be credited to your '
                            'wallet once we have verified your payment.',
                            style: const TextStyle(
                                fontSize: 13, color: _kBlue, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Go Back Home button ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            child: SizedBox(
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
                  'Go Back Home',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
