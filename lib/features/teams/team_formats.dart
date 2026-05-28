/// Komandos formato apibrėžimas
library;

class TeamFormat {

  final String code;

  final String label;

  final int playersOnCourt;

  final int maxTeamSize;

  final String? description;



  const TeamFormat({

    required this.code,

    required this.label,

    required this.playersOnCourt,

    required this.maxTeamSize,

    this.description,

  });



  int get minTeamSize => playersOnCourt;

}



/// Formatai pagal sportą (sutapatinta su sports_catalog.name)

class TeamFormatCatalog {

  static const Map<String, List<TeamFormat>> _catalog = {

    'Tenisas': [

      TeamFormat(code: '1v1', label: '1v1 (vienetai)', playersOnCourt: 1, maxTeamSize: 1),

      TeamFormat(code: '2v2', label: '2v2 (dvejetai)', playersOnCourt: 2, maxTeamSize: 2),

    ],

    'Padelis': [

      TeamFormat(code: '2v2', label: '2v2', playersOnCourt: 2, maxTeamSize: 2),

    ],

    'Pickleball': [

      TeamFormat(code: '1v1', label: '1v1', playersOnCourt: 1, maxTeamSize: 1),

      TeamFormat(code: '2v2', label: '2v2', playersOnCourt: 2, maxTeamSize: 2),

    ],

    'Badmintonas': [

      TeamFormat(code: '1v1', label: '1v1', playersOnCourt: 1, maxTeamSize: 1),

      TeamFormat(code: '2v2', label: '2v2', playersOnCourt: 2, maxTeamSize: 2),

    ],

    'Skvošas': [

      TeamFormat(code: '1v1', label: '1v1', playersOnCourt: 1, maxTeamSize: 1),

    ],

    'Stalo tenisas': [

      TeamFormat(code: '1v1', label: '1v1', playersOnCourt: 1, maxTeamSize: 1),

      TeamFormat(code: '2v2', label: '2v2', playersOnCourt: 2, maxTeamSize: 2),

    ],

    'Krepšinis': [

      TeamFormat(code: '3x3', label: '3x3', playersOnCourt: 3, maxTeamSize: 5, description: '3 aikštelėje + rezervas'),

      TeamFormat(code: '5v5', label: '5v5', playersOnCourt: 5, maxTeamSize: 12),

    ],

    'Futbolas': [

      TeamFormat(code: '5v5', label: '5v5', playersOnCourt: 5, maxTeamSize: 10),

      TeamFormat(code: '7v7', label: '7v7', playersOnCourt: 7, maxTeamSize: 12),

      TeamFormat(code: '11v11', label: '11v11', playersOnCourt: 11, maxTeamSize: 18),

    ],

    'Tinklinis': [

      TeamFormat(code: '6x6', label: '6x6', playersOnCourt: 6, maxTeamSize: 12),

      TeamFormat(code: '4x4', label: '4x4', playersOnCourt: 4, maxTeamSize: 8),

    ],

    'Paplūdimio tinklinis': [

      TeamFormat(code: '2v2', label: '2v2', playersOnCourt: 2, maxTeamSize: 3),

      TeamFormat(code: '4v4', label: '4v4', playersOnCourt: 4, maxTeamSize: 6),

    ],

    'Smiginis': [

      TeamFormat(code: '1v1', label: '1v1', playersOnCourt: 1, maxTeamSize: 1),

      TeamFormat(code: '2v2', label: '2v2 (poros)', playersOnCourt: 2, maxTeamSize: 2),

    ],

    'Boulingas': [

      TeamFormat(code: '1v1', label: '1v1', playersOnCourt: 1, maxTeamSize: 1),

      TeamFormat(code: '2v2', label: '2v2 (poros)', playersOnCourt: 2, maxTeamSize: 2),

    ],

    'Biliardas': [

      TeamFormat(code: '1v1', label: '1v1', playersOnCourt: 1, maxTeamSize: 1),

    ],

    'Poolas': [

      TeamFormat(code: '1v1', label: '1v1', playersOnCourt: 1, maxTeamSize: 1),

      TeamFormat(code: '2v2', label: '2v2', playersOnCourt: 2, maxTeamSize: 2),

    ],

    'Snukeris': [

      TeamFormat(code: '1v1', label: '1v1', playersOnCourt: 1, maxTeamSize: 1),

    ],

    'Dažasvydis': [

      TeamFormat(code: '5v5', label: '5v5', playersOnCourt: 5, maxTeamSize: 10),

      TeamFormat(code: '7v7', label: '7v7', playersOnCourt: 7, maxTeamSize: 14),

    ],

    'Rankinis': [

      TeamFormat(code: '6v6', label: '6v6', playersOnCourt: 6, maxTeamSize: 12),

      TeamFormat(code: '7v7', label: '7v7', playersOnCourt: 7, maxTeamSize: 14),

    ],

  };



  static const TeamFormat custom = TeamFormat(

    code: 'custom',

    label: 'Pasirinktinis formatas...',

    playersOnCourt: 0,

    maxTeamSize: 0,

  );



  static List<TeamFormat> getFormats(String sport) {

    return List.from(_catalog[sport] ?? [const TeamFormat(code: '1v1', label: '1v1', playersOnCourt: 1, maxTeamSize: 1)]);

  }



  static bool hasTemplates(String sport) {

    return _catalog.containsKey(sport) && _catalog[sport]!.isNotEmpty;

  }



  /// Pagal sports_catalog.allowed_formats (Fazė 1).

  static List<TeamFormat> fromAllowedFormats(List<String> codes) {

    final known = <String, TeamFormat>{};

    for (final list in _catalog.values) {

      for (final f in list) {

        known[f.code] = f;

      }

    }

    final out = <TeamFormat>[];

    for (final code in codes) {

      out.add(known[code] ?? _guessFormat(code));

    }

    return out.isEmpty ? [const TeamFormat(code: '1v1', label: '1v1', playersOnCourt: 1, maxTeamSize: 1)] : out;

  }



  static TeamFormat _guessFormat(String code) {

    final m = RegExp(r'^(\d+)v(\d+)$', caseSensitive: false).firstMatch(code);

    if (m != null) {

      final n = int.parse(m.group(1)!);

      return TeamFormat(

        code: code,

        label: code,

        playersOnCourt: n,

        maxTeamSize: n * 2,

      );

    }

    return TeamFormat(code: code, label: code, playersOnCourt: 1, maxTeamSize: 1);

  }

}


