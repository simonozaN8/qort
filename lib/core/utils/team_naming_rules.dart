/// Komandų / porų pavadinimų taisyklės pagal sportą.
class TeamNamingRules {
  TeamNamingRules._();

  /// Tenisas, padelis ir pan.: poroje rodomi žaidėjų vardai ir pavardės.
  static bool usesParticipantNames(String sport, String? formatCode) {
    const pairBySport = {
      'Tenisas',
      'Padelis',
      'Badmintonas',
      'Stalo tenisas',
      'Pickleball',
    };
    if (!pairBySport.contains(sport)) return false;
    if (formatCode == null || formatCode == '2v2') return true;
    return formatCode == '1v1';
  }

  static String nameFieldHint(String sport, String? formatCode) {
    if (usesParticipantNames(sport, formatCode)) {
      return 'Pvz.: Jonas Petraitis / Marius Kazlauskas';
    }
    return 'Pvz.: Vilniaus 3x3, „Aikštelės vilkai“';
  }

  static String infoBoxText(String sport, String? formatCode) {
    if (!usesParticipantNames(sport, formatCode)) return '';
    if (formatCode == '1v1') {
      return 'Vienetuose komanda = jūsų vardas ir pavardė (kaip turnyro dalyvio vardas).';
    }
    return 'Šiame sporte poros/komandos pavadinimas = kiekvieno žaidėjo vardas ir pavardė, '
        'atskirti „ / “ (pvz. Jonas Petraitis / Marius Kazlauskas). '
        'Pridėjus narius profilyje pavadinimas gali būti atnaujintas automatiškai.';
  }

  /// Vardas rodymui iš profilio įrašo.
  static String displayNameFromProfile(Map<String, dynamic> profile) {
    final nick = profile['nickname']?.toString().trim() ?? '';
    if (nick.isNotEmpty) return nick;
    final name = profile['name']?.toString().trim() ?? '';
    final surname = profile['surname']?.toString().trim() ?? '';
    final full = '$name $surname'.trim();
    return full.isNotEmpty ? full : 'Žaidėjas';
  }

  static String buildFromProfiles(List<Map<String, dynamic>> profiles) {
    if (profiles.isEmpty) return 'Komanda';
    return profiles.map(displayNameFromProfile).join(' / ');
  }
}
