import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/qort_colors.dart';

/// Bendros instrukcijos formoms (turnyrai, rezultatai, tvarkaraštis, skelbimai).
class QortFormHelpTexts {
  QortFormHelpTexts._();

  static const tournamentCreate = [
    'Užpildykite renginio informaciją, tada pridėkite kategorijas (divizionus) — kiekviena tampa atskiru turnyru.',
    'RP (Rating Points) — turnyro taškų bankas: nugalėtojas gauna didžiausią dalį, kitos vietos — pagal etapą ir medį.',
    'Kategorijų lygių diapazonas turi atitikti sporto katalogą (pvz. tenisui — NTRP, kitoms šakoms — savo skalę).',
    'Po sukūrimo mačų rezultatus įveda organizatorius arba žaidėjai (pagal nustatytą tvarkaraščio tipą).',
  ];

  static const tournamentRp = [
    'RP vertė — kiek taškų iš viso išdalins turnyras tarp dalyvių (pagal vietas / etapus).',
    'Min. RP / XP — registracijos slenkstis; žaidėjai žemesniu reitingu negalės registruotis.',
  ];

  static const bulkSchedule = [
    'Pasirinkite datą ir laiką kiekvienam mačui — jie matysis dalyviams skiltyje „Mačai“.',
    'Arena — bendra vieta (klubas, salė); kortas / aikštelė — konkretus numeris ar pavadinimas.',
    'Laikas neprivalomas — galite palikti „Nepasirinkta“, kol susitarsite su žaidėjais.',
    'Oranžinis laikrodžio mygtukas viršuje pastumia visų jau nustatytų laikų pradžią +30 min.',
  ];

  static const scoreEntry = [
    'Įveskite kiekvieno seto rezultatą (pvz. 6:4). TB — tie-break skliausteliuose, jei buvo.',
    'Laimėtojas skaičiuojamas pagal laimėtus setus; pilnas rezultatas rodomas kaip „6:4, 3:6, 10:7“.',
    'Admin režime galite koreguoti net patvirtintus mačus — naudokite atsargiai.',
  ];

  static const matchesTab = [
    '„Laukia“ — dar nėra laiko ar rezultato. Oficialus laikas rodomas žaliai, jei tvarkaraštį veda organizatorius.',
    'Admin: kalendorius — planuoti; žalia play — aktyvuoti; pieštukas — įvesti ar taisyti rezultatą.',
    'Žaidėjai gali siūlyti laiką patys, jei turnyre pasirinktas laisvas derinimas.',
  ];

  static const externalRecordIntro =
      'Tik įvykiai NE QORT sistemoje: draugiškas mačas kitur, turnyras kitoje platformoje, '
      'galutinė vieta. QORT turnyrų mačus įvedi iš Pagrindinio, kai sistema paprašo.';
  static const externalRecordDate =
      'Kada žaidėte. Galite pasirinkti bet kurią datą iki šiandienos.';
  static const externalRecordType =
      'Draugiškas — vienas mačas su varžovu. Turnyras — varžybos QORT ar kitoje vietoje; '
      'galite įrašyti ir galutinę vietą.';
  static const externalRecordTournamentSource =
      'Tik turnyras, kuris nevyko QORT platformoje. QORT turnyrų vietą ir mačus '
      'įvedi iš Pagrindinio ekrano.';
  static const externalRecordPlacement =
      'Kai turnyras baigtas — įrašykite vietą (pvz. 3 iš 16). Jei žaidėte tik vieną mačą, '
      'užpildykite ir rezultatą žemiau.';
  static const externalRecordScore =
      'Įveskite setus arba vieną bendrą rezultatą. Pasirinkite, ar laimėjote — '
      'tai svarbu statistikai ir pasiekimams.';

  static const trainingListing = [
    'Lygiai imami iš jūsų profilio ir sporto katalogo (NTRP tenisui, lygiai kitoms šakoms).',
    'Slankikliu nurodykite, kokio lygio varžovų ieškote — matys tik atitinkantys žaidėjai.',
    'Data ir laikas — kada norite žaisti; miestas / arena padeda rasti artimiausius skelbimus.',
  ];

  // —— Turnyro kūrimas (konkretūs laukai) ——
  static const createEventName =
      'Oficialus renginio pavadinimas. Matomas turnyrų sąraše, ant viršelio ir kvietimuose.';
  static const createSport =
      'Pasirinkite sporto šaką — nuo jos priklauso galimi formatai (1v1, 2v2 ir t. t.) kategorijose.';
  static const createLocation =
      'Miestas ar arena, kur vyks renginys. Naudojama filtrams ir dalyvių orientacijai.';
  static const createDescription =
      'Trumpas aprašymas dalyviams: formato ypatumai, prizai, kontaktai (neprivaloma).';
  static const createRules =
      'Taisyklės ar specialūs reikalavimai (apranga, laiko limitai, W/O tvarka).';
  static const createMinAge =
      'Mažiausias amžius registracijai. 0 arba tuščia = be apatinės ribos.';
  static const createMaxAge =
      'Didžiausias amžius registracijai. 99 = be viršutinės ribos.';
  static const createMinRp =
      'Minimalus RP (reitingas) registracijai. Žaidėjai žemesniu RP negalės registruotis.';
  static const createMinXp =
      'Minimalus XP (patirtis) registracijai. Naudinga naujokų ar veteranų turnyrams.';
  static const createOrganizer =
      'Organizatoriaus pavadinimas ar kontaktas — rodomas renginio kortelėje.';
  static const createOrganizerNote =
      'Papildoma žinutė QORT adminui (paraiškų režime) arba trumpas kontaktas dalyviams.';
  static const createSponsor =
      'Pagrindinis rėmėjas — logotipas gali būti įkeltas atskirai žemiau.';
  static const createStartDate =
      'Renginio pradžios data. Nuo jos skaičiuojamas viešas „artėja“ statusas.';
  static const createEndDate =
      'Renginio pabaigos data. Turi būti ne ankstesnė už pradžią.';
  static const createPrice =
      'Dalyvio mokestis eurais vienam turnyrui / kategorijai (jei taikoma).';
  static const createMaxParticipants =
      'Maksimalus dalyvių skaičius vienai kategorijai prieš uždarant registraciją.';
  static const createRpValue =
      'Bendras RP „bankas“ turnyrui: sistema dalins taškus pagal vietas ir etapus po turnyro.';

  // —— Valdymo pultas: diviziono etapai ——
  static const stageFormat =
      'Etapo logika: grupės (Round Robin), Šveicarijos, atkrintamosios, kvalifikacija ar paguodos etapas.';
  static const stageScheduling =
      'Kas planuoja mačų laikus: tik žaidėjai, tik organizatorius ar mišrus režimas nuo atkrintamųjų.';
  static const stageStartDate =
      'Etapo pradžios data tęstiniams turnyrams. Tuščia — etapas be fiksuoto termino.';
  static const stageEndDate =
      'Etapo pabaigos data. Naudinga riboti registraciją ar grupių etapą kalendoriuje.';
  static const stageGroupCount =
      'Į kiek grupių padalinti dalyvius. Sistema paskirstys balansuotai pagal reitingą.';
  static const stageAdvancing =
      'Kiek geriausių iš kiekvienos grupės patenka į kitą etapą ar atkrintamąsias.';
  static const stageAllowTies =
      'Jei įjungta — grupėje leidžiamos lygiosios; atsiranda taškai už lygiąsias.';
  static const stagePointsWin =
      'Taškai lentelėje už pergalę grupėje (pvz. 3 kaip futbolo sistema).';
  static const stagePointsTie =
      'Taškai už lygiąsias grupėje (dažniausiai 1).';
  static const stagePointsLoss =
      'Taškai už pralaimėjimą (dažnai 0).';
  static const stagePlayoffPlaces =
      'Kiek vietų žaidžia atkrintamųjų medyje (tik nugalėtojas, top 3, top 8 ir pan.).';
  static const stageAdvanceTo =
      'Kur automatiškiai keliauja laimėtojai / išeinantys po šio etapo (kitas etapas arba „Nėra“).';
  static const stageDropTo =
      'Kur keliauja pralaimėtojai — pvz. į paguodos turnyrą arba išmetami.';
  static const adminVenueType =
      'Kaip sistemoje vadinsime vietas (kortas, aikštelė, ringas). Matoma tvarkaraštyje ir mačuose.';
}

/// Etiketė su (?) — paspaudus rodo paaiškinimą po lauku.
class QortFieldHelpLabel extends StatefulWidget {
  final String label;
  final String help;
  final TextStyle? labelStyle;

  const QortFieldHelpLabel({
    super.key,
    required this.label,
    required this.help,
    this.labelStyle,
  });

  @override
  State<QortFieldHelpLabel> createState() => _QortFieldHelpLabelState();
}

class _QortFieldHelpLabelState extends State<QortFieldHelpLabel> {
  bool _showHelp = false;

  void _toggle() => setState(() => _showHelp = !_showHelp);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: widget.labelStyle ??
                        const TextStyle(
                          color: QortColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Icon(
                  _showHelp ? LucideIcons.chevronUp : LucideIcons.info,
                  size: 18,
                  color: QortColors.primary,
                ),
              ],
            ),
          ),
        ),
        if (_showHelp) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: QortColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: QortColors.border),
            ),
            child: Text(
              widget.help,
              style: const TextStyle(
                color: QortColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
      ],
    );
  }
}

/// Informacinis blokas formų viršuje arba dialoge.
class QortHelpBanner extends StatelessWidget {
  final String? title;
  final List<String> bullets;
  final IconData icon;
  final Color? accentColor;

  const QortHelpBanner({
    super.key,
    this.title,
    required this.bullets,
    this.icon = LucideIcons.info,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? QortColors.primary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title ?? 'Kaip užpildyti',
                  style: const TextStyle(
                    color: QortColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        color: QortColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Šviesus dialogas (tamsiame fone naudojamas `textPrimary` — neįskaitoma).
class QortFormDialog {
  QortFormDialog._();

  static AlertDialog shell({
    required Widget title,
    required Widget content,
    List<Widget>? actions,
  }) {
    return AlertDialog(
      backgroundColor: QortColors.surface,
      surfaceTintColor: QortColors.surface,
      title: DefaultTextStyle(
        style: const TextStyle(color: QortColors.textPrimary),
        child: title,
      ),
      content: DefaultTextStyle(
        style: const TextStyle(color: QortColors.textPrimary),
        child: content,
      ),
      actions: actions,
    );
  }

  static Widget cancelButton(BuildContext context, {String label = 'ATŠAUKTI'}) {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(
        label,
        style: const TextStyle(
          color: QortColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
