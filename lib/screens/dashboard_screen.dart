import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/crypto_service.dart';
import '../../services/wallet_service.dart';
import 'auth/sign_in_screen.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/coin_logo.dart';
import 'giftcard/giftcard_menu_screen.dart';
import 'crypto/buy_crypto_screen.dart';
import 'crypto/transfer_crypto_screen.dart';
import 'crypto/deposit_crypto_screen.dart';
import 'crypto/swap_crypto_screen.dart';
import 'crypto/my_crypto_screen.dart';
import 'wallet/ngn_wallet_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/transaction_history_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBg = Color(0xFFF2F4F8);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _activeNav = 0;
  bool _isLoading = true;
  String? _error;
  String _ngnBalance = '₦0.00';
  bool _balanceLoading = true;
  bool _balanceHidden = false;
  List<CoinInfo> _coins = [];
  bool _pricesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadUser(), _loadBalance(), _loadPrices()]);
  }

  Future<void> _loadPrices() async {
    try {
      final data = await CryptoService.getPrices();
      if (!mounted) return;
      setState(() {
        _coins = data.coins;
        _pricesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pricesLoading = false);
    }
  }

  Future<void> _loadUser() async {
    try {
      await AuthService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = null;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBalance() async {
    try {
      final info = await WalletService.getWallet();
      if (!mounted) return;
      setState(() {
        _ngnBalance = _formatNgn(info.ngnBalance);
        _balanceLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _balanceLoading = false);
    }
  }

  static String _formatNgn(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '₦$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      final isSessionExpired = _error == kSessionExpiredError;
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSessionExpired
                        ? kSessionExpiredError
                        : _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _kDark),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isSessionExpired
                        ? () async {
                            final nav = Navigator.of(context);
                            await AuthService.clearSession();
                            if (!mounted) return;
                            nav.pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const SignInScreen()),
                              (_) => false,
                            );
                          }
                        : () {
                            setState(() {
                              _isLoading = true;
                              _balanceLoading = true;
                              _error = null;
                            });
                            _loadAll();
                          },
                    child: Text(isSessionExpired ? 'Sign In' : 'Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NgnWalletScreen()),
        ).then((_) { if (mounted) _loadBalance(); }),
        backgroundColor: _kBlue,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() { _balanceLoading = true; });
            await _loadBalance();
          },
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              ValueListenableBuilder<AuthUser?>(
                valueListenable: AuthService.currentUserNotifier,
                builder: (context, user, _) {
                  if (user == null) return const SizedBox.shrink();
                  return _buildBalanceCard();
                },
              ),
              const SizedBox(height: 24),
              _buildQuickLinks(),
              const SizedBox(height: 24),
              _buildServices(),
              const SizedBox(height: 24),
              _buildTabSelector(),
              const SizedBox(height: 16),
              _buildPortfolio(),
              const SizedBox(height: 24),
            ],
          ),
          ),  // SingleChildScrollView
        ),    // RefreshIndicator
      ),      // SafeArea
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return ValueListenableBuilder<AuthUser?>(
      valueListenable: AuthService.currentUserNotifier,
      builder: (context, user, _) {
        final name = user?.fullName ?? '';
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ProfileAvatar(user: user, radius: 22),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: _kDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Welcome Back 👋',
                        style: TextStyle(fontSize: 14, color: _kGrey),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    size: 22,
                    color: _kDark,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Balance card ────────────────────────────────────────────────────────────

  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: _kBlue.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF16299E), _kBlue, Color(0xFF2C46D6)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -40,
                  top: -55,
                  child: _balanceRingDecor(170),
                ),
                Positioned(
                  right: -20,
                  bottom: -65,
                  child: _balanceRingDecor(140),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current Balance',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(
                              () => _balanceHidden = !_balanceHidden,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _balanceHidden
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _balanceLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _balanceHidden ? '₦ • • • • • •' : _ngnBalance,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.0,
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
      ),
    );
  }

  Widget _balanceRingDecor(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 18,
        ),
      ),
    );
  }

  // ── Quick links ─────────────────────────────────────────────────────────────

Widget _buildQuickLinks() {
  const links = [
    _QuickLinkData(
      label: 'Send',
      icon: Icons.north_east_rounded,
      screen: TransferCryptoScreen(),
    ),
    _QuickLinkData(
      label: 'Receive',
      icon: Icons.south_west_rounded,
      screen: DepositCryptoScreen(),
    ),
    _QuickLinkData(
      label: 'Swap',
      icon: FontAwesomeIcons.rightLeft,
      screen: SwapCryptoScreen(),
    ),
    _QuickLinkData(
      label: 'Buy & Sell',
      icon: FontAwesomeIcons.creditCard,
      screen: BuyCryptoScreen(),
    ),
  ];

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: links.map((link) {
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => link.screen),
              ),
              child: SizedBox(
                width: 72,
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FB),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          link.icon,
                          size: 22,
                          color: const Color(0xFF2457F5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      link.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

  // ── Services ────────────────────────────────────────────────────────────────

  Widget _buildServices() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Giftcards
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GiftcardMenuScreen(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.card_giftcard_outlined,
                            size: 20,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Flexible(
                          child: Text(
                            'Giftcards',
                            style: TextStyle(
                              fontSize: 15,
                              color: _kDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Buy Crypto
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BuyCryptoScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // Stacked coin icons
                        SizedBox(
                          height: 38,
                          width: 64,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                top: 3,
                                child: _CoinBadge(
                                  iconData: FontAwesomeIcons.bitcoin,
                                  color: const Color(0xFFF7931A),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                top: 3,
                                child: _CoinBadge(
                                  iconData: FontAwesomeIcons.ethereum,
                                  color: const Color(0xFF627EEA),
                                ),
                              ),
                              Positioned(
                                left: 32,
                                top: 3,
                                child: _CoinBadge(
                                  iconData: null,
                                  color: const Color(0xFF26A17B),
                                  letter: 'T',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'Buy Crypto',
                            style: TextStyle(
                              fontSize: 15,
                              color: _kDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab selector ─────────────────────────────────────────────────────────────

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 57, vertical: 8),
            decoration: BoxDecoration(
              color: _kBlue,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Tokens',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TransactionHistoryScreen(),
              ),
            ),
            child: const Text(
              'Transaction History',
              style: TextStyle(
                color: _kGrey,
                fontWeight: FontWeight.normal,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Portfolio ────────────────────────────────────────────────────────────────

  Widget _buildPortfolio() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Market Prices',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kDark,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _pricesLoading = true);
                  _loadPrices();
                },
                child: const Text(
                  'Refresh',
                  style: TextStyle(
                    color: _kBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_pricesLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: _kBlue),
              ),
            )
          else if (_coins.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Could not load prices.',
                  style: TextStyle(color: _kGrey, fontSize: 14)),
            )
          else
            // Two cards per row
            ...List.generate((_coins.length / 2).ceil(), (rowIndex) {
              final left = _coins[rowIndex * 2];
              final rightIndex = rowIndex * 2 + 1;
              final right =
                  rightIndex < _coins.length ? _coins[rightIndex] : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: _PortfolioCard.fromCoin(left)),
                    const SizedBox(width: 12),
                    right != null
                        ? Expanded(child: _PortfolioCard.fromCoin(right))
                        : const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black12,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: _activeNav == 0,
              onTap: () => setState(() => _activeNav = 0),
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Wallet',
              active: _activeNav == 1,
              onTap: () {
                setState(() => _activeNav = 1);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NgnWalletScreen()),
                ).then((_) { if (mounted) _loadBalance(); });
              },
            ),
            const SizedBox(width: 40), // FAB space
            _NavItem(
              icon: Icons.currency_bitcoin_rounded,
              label: 'Crypto',
              active: _activeNav == 2,
              onTap: () {
                setState(() => _activeNav = 2);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyCryptoScreen(),
                  ),
                );
              },
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              active: _activeNav == 3,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _QuickLinkData {
  final String label;
  final IconData icon;
  final Widget screen;
  final bool highlighted;

  const _QuickLinkData({
    required this.label,
    required this.icon,
    required this.screen,
    this.highlighted = false,
  });
}

class _QuickLinkTile extends StatelessWidget {
  final _QuickLinkData data;
  final VoidCallback onTap;

  const _QuickLinkTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = data.highlighted ? _kBlue : Colors.white;
    final fg = data.highlighted ? Colors.white : _kDark;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        splashColor: _kBlue.withValues(alpha: 0.1),
        highlightColor: _kBlue.withValues(alpha: 0.05),
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: data.highlighted
                ? null
                : Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  final Color color;
  final IconData? iconData;
  final String? letter;
  const _CoinBadge({required this.color, this.iconData, this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: iconData != null
          ? Icon(iconData, color: Colors.white, size: 18)
          : (letter != null
                ? Text(
                    letter!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const SizedBox.shrink()),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final String name;
  final String ticker;
  final String priceNgn;
  final Color coinColor;
  final String letter;
  final String? logoUrl;

  const _PortfolioCard({
    required this.name,
    required this.ticker,
    required this.priceNgn,
    required this.coinColor,
    required this.letter,
    required this.logoUrl,
  });

  factory _PortfolioCard.fromCoin(CoinInfo coin) {
    final price = coin.priceNgn;
    String formatted;
    if (price == 0) {
      formatted = '—';
    } else if (price >= 1000000) {
      formatted = '₦${(price / 1000000).toStringAsFixed(2)}M';
    } else if (price >= 1000) {
      formatted = '₦${(price / 1000).toStringAsFixed(2)}K';
    } else {
      formatted = '₦${price.toStringAsFixed(2)}';
    }
    return _PortfolioCard(
      name: coin.name,
      ticker: coin.symbol,
      priceNgn: formatted,
      coinColor: coin.color,
      letter: coin.letter,
      logoUrl: coin.logoUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              CoinLogo(
                logoUrl: logoUrl,
                letter: letter,
                letterColor: coinColor,
                backgroundColor: coinColor.withValues(alpha: 0.15),
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(ticker,
              style: const TextStyle(fontSize: 13, color: _kGrey)),
          const SizedBox(height: 10),
          Text(
            priceNgn,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'per coin',
            style: TextStyle(fontSize: 12, color: _kGrey),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _kBlue : _kGrey;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
