/// Mačų rezultatų patvirtinimo ir auto-complete laiko konstantos.
class MatchConstants {
  MatchConstants._();

  /// Kiek laiko varžovas turi patvirtinti rezultatą prieš auto-complete.
  static const Duration scoreConfirmationTimeout = Duration(hours: 1);

  /// UI tekstas lietuviškai (pvz. „1 val.“).
  static String get confirmationTimeoutLabel {
    final hours = scoreConfirmationTimeout.inHours;
    if (hours > 0) return '$hours val.';
    return '${scoreConfirmationTimeout.inMinutes} min.';
  }

  /// Užbaigimo pastaba auto-patvirtinimui.
  static String get autoConfirmCompletionNote =>
      'Auto-confirmed (${scoreConfirmationTimeout.inHours}h)';
}
