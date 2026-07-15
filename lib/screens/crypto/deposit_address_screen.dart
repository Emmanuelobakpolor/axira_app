import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/auth_service.dart' show AuthException;
import '../../services/crypto_service.dart';
import '../../utils/session_guard.dart';
import '../../widgets/coin_logo.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);
const _kDisabled = Color(0xFFBFD7FC);

// ─── Deposit Address Screen ───────────────────────────────────────────────────

class DepositAddressScreen extends StatefulWidget {
  final CoinInfo coin;
  final String network;

  const DepositAddressScreen({
    super.key,
    required this.coin,
    required this.network,
  });

  @override
  State<DepositAddressScreen> createState() => _DepositAddressScreenState();
}

class _DepositAddressScreenState extends State<DepositAddressScreen> {
  bool _loading = true;
  String _error = '';
  String _address = '';

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final address = await CryptoService.getDepositAddress(
        widget.coin.symbol,
        network: widget.network,
      );
      if (!mounted) return;
      setState(() {
        _address = address;
        _loading = false;
      });
    } on AuthException catch (_) {
      if (!mounted) return;
      await redirectToSignIn(context);
    } on CryptoException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<String> get _notes => [
        if (widget.network.isNotEmpty)
          'This address is specific to the ${widget.network} network and the ${widget.coin.symbol} token — sending any other asset or using a different network may lose your funds.'
        else
          'Only send ${widget.coin.symbol} to this address — sending any other asset may lose your funds.',
        'Deposits are usually credited within a few minutes after blockchain confirmation.',
        'Dealing with sanctioned entities should be avoided.',
        'Please refrain from depositing coins that have been stolen or are fake, since this will cause your account to be frozen.',
      ];

  void _copy() {
    if (_address.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
          'Deposit Crypto',
          style: TextStyle(
              color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : _error.isNotEmpty
              ? _ErrorState(message: _error, onRetry: _loadAddress)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Selected Token ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    children: [
                      CoinLogo(
                        logoUrl: widget.coin.logoUrl,
                        letter: widget.coin.letter,
                        letterColor: widget.coin.color,
                        backgroundColor:
                            widget.coin.color.withValues(alpha: 0.15),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(widget.coin.symbol,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _kDark)),
                    ],
                  ),
                ),

                // ── Selected Network ──────────────────────────────────
                if (widget.network.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        Text(widget.network,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _kDark)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // ── Scan label ────────────────────────────────────────
                const Text(
                  'Scan to send token or copy address to pay',
                  style: TextStyle(
                      fontSize: 13,
                      color: _kGrey,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // ── QR Code ───────────────────────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: SizedBox(
                      width: 160,
                      height: 160,
                      child: QrImageView(
                        data: _address,
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: _kDark,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: _kDark,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Wallet Address ────────────────────────────────────
                const Text(
                  'Wallet Address',
                  style: TextStyle(fontSize: 12, color: _kGrey),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _address,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _kDark,
                            height: 1.4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _copy,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.copy_rounded,
                            size: 18, color: _kBlue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Please Note box ───────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF4FF),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFBFD7FC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: _kBlue),
                          const SizedBox(width: 6),
                          const Text(
                            'Please Note:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._notes.map(
                        (n) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: _kBlue,
                                      height: 1.5)),
                              Expanded(
                                child: Text(
                                  n,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: _kBlue,
                                      height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Buttons ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          child: Column(
            children: [
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
                    'Noted',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _address.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: _address));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Address copied for sharing'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kDisabled,
                    disabledBackgroundColor: _kDisabled.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Share',
                    style: TextStyle(
                        color: _kBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kGrey, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
              child:
                  const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
