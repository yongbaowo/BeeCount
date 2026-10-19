/// This checkout is the personal edition by default. The upstream interface can
/// still be built explicitly with --dart-define=BEECOUNT_PERSONAL=false.
const personalEdition =
    bool.fromEnvironment('BEECOUNT_PERSONAL', defaultValue: true);

/// A client-side capability switch, not a server authorization mechanism.
const sharedLedgersEnabled = !personalEdition;

void requireSharedLedgers() {
  if (!sharedLedgersEnabled) {
    throw UnsupportedError('此版本仅支持个人账本');
  }
}
