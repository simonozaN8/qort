/// Centralizuota vietinio (LT) ir UTC laiko konversija Supabase timestamptz laukams.
class DateTimeUtils {
  DateTimeUtils._();

  /// LT laiką paverčia UTC ISO string DB rašymui.
  /// Naudoti VISADA prieš siunčiant į Supabase timestamptz lauką.
  static String toIsoUtc(DateTime localDt) {
    return localDt.toUtc().toIso8601String();
  }

  /// DB ISO string paverčia LT DateTime rodymui.
  static DateTime fromIso(String iso) {
    return DateTime.parse(iso).toLocal();
  }
}
