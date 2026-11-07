/// Services that need Axira's own liquidity (NGN to buy crypto, both legs of
/// a swap, a prefunded Reloadly balance for gift cards) are off for launch.
/// Flip one to true — together with its FEATURE_* env var on the backend —
/// to switch it back on.
const bool kBuyCryptoEnabled = false;
const bool kSwapCryptoEnabled = false;
const bool kBuyGiftcardEnabled = false;
