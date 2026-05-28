/// Organizatorių renginių politika (mokama paslauga + moderacija).
class EventOrganizerPolicy {
  EventOrganizerPolicy._();

  /// Bazinė platformos paslaugos kaina (EUR). Mokėjimo integracija — vėliau.
  static const double serviceFeeEur = 49.0;

  static const approvalPending = 'pending';
  static const approvalApproved = 'approved';
  static const approvalRejected = 'rejected';

  static const paymentUnpaid = 'unpaid';
  static const paymentConfirmed = 'confirmed';

  static String feeLabel() => '${serviceFeeEur.toStringAsFixed(0)} €';

  static const submissionBannerText =
      'Renginys viešai pasirodys tik po QORT administratoriaus / savininko '
      'patvirtinimo. Tai apsaugo platformą nuo nekokybiškų ar šiukšlinių turnyrų. '
      'Mokėjimas už organizavimo paslaugą suderinamas su komanda po paraiškos.';

  static String get termsCheckboxLabel =>
      'Suprantu, kad tai mokama paslauga (${feeLabel()}) '
      'ir renginys bus publikuojamas tik po QORT patvirtinimo.';
}
