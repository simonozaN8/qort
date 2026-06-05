import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/event_organizer_policy.dart';
import '../../core/models/sport_catalog_entry.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/services/event_sponsor_service.dart';
import '../../core/services/pricing_tier_service.dart';
import '../../core/services/rules_template_service.dart';
import '../../core/utils/datetime_utils.dart';
import '../../core/utils/sport_levels.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/widgets/qort_form_help.dart';
import '../../core/widgets/tournament_cover_color_filters.dart';
import '../teams/team_formats.dart';
import 'tournament_composer_widget.dart';
import 'tournament_composer_preview.dart';
import 'tournament_draft_preview_screen.dart';
import 'tournament_sponsor_band.dart';

class CreateEventScreen extends StatefulWidget {
  /// Redagavimo režimas — krauna esamą renginį ir UPDATE vietoj INSERT.
  final String? editEventId;

  const CreateEventScreen({super.key, this.editEventId});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  static const List<String> _sponsorLabelSuggestions = [
    "Generalinis rėmėjas",
    "Mecenatas",
    "Aukso rėmėjas",
    "Sidabro rėmėjas",
    "Partneris",
    "Bendradarbis",
  ];
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();
  final _rulesFieldKey = GlobalKey();
  final _prizeCtrl = TextEditingController();
  final _prizesInfoCtrl = TextEditingController();
  final _maxParticipantsCtrl = TextEditingController(text: "16");
  final _rpValueCtrl = TextEditingController(text: "1000");
  final List<_PricingTierDraft> _pricingTiers = [
    _PricingTierDraft(name: 'Įprasta', priceText: '20'),
  ];
  DateTime? _registrationDeadline;
  final _organizerCtrl = TextEditingController();
  final _organizerEmailCtrl = TextEditingController();
  final _organizerPhoneCtrl = TextEditingController();
  final _organizerNoteCtrl = TextEditingController();

  final _minAgeCtrl = TextEditingController(text: "16");
  final _maxAgeCtrl = TextEditingController(text: "99");
  bool _isPrivate = false;

  final _minRpCtrl = TextEditingController(text: "0");
  final _minXpCtrl = TextEditingController(text: "0");

  String _selectedSport = "Tenisas";
  List<String> _sportOptions = ["Tenisas"];
  SportCatalogEntry? _sportEntry;
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  DateTime _endDate = DateTime.now().add(const Duration(days: 14));
  bool _isLoading = false;

  File? _coverImageFile;
  Uint8List? _coverImageBytes;
  bool _flipHorizontal = false;
  String _coverFilterPreset = 'original';
  // Sponsor logotipai dabar per `event_sponsors` lentelę.
  final List<_SponsorDraft> _sponsors = [];

  final List<Map<String, dynamic>> _divisions = [];
  final ImagePicker _picker = ImagePicker();
  String? _existingCoverUrl;
  bool _loadingEdit = false;

  bool get _isEditMode => widget.editEventId != null;

  @override
  void initState() {
    super.initState();
    _loadSportOptions();
    if (_isEditMode) {
      _loadEventForEdit();
    }
  }

  Future<void> _loadEventForEdit() async {
    final eventId = widget.editEventId;
    if (eventId == null) return;

    setState(() => _loadingEdit = true);
    try {
      final data = await Supabase.instance.client
          .from('events')
          .select('*, tournaments(*), pricing_tiers(*), event_sponsors(*)')
          .eq('id', eventId)
          .single();

      final eventMap = Map<String, dynamic>.from(data as Map);
      final eventName = eventMap['name']?.toString() ?? '';
      final tournaments = (eventMap['tournaments'] as List?) ?? const [];

      _nameCtrl.text = eventName;
      _locationCtrl.text = eventMap['location']?.toString() ?? '';
      _descriptionCtrl.text = eventMap['description']?.toString() ?? '';
      _rulesCtrl.text = eventMap['rules']?.toString() ?? '';
      _prizesInfoCtrl.text = eventMap['prizes_info']?.toString() ?? '';
      _organizerCtrl.text = eventMap['organizer']?.toString() ?? '';
      _organizerEmailCtrl.text = eventMap['organizer_email']?.toString() ?? '';
      _organizerPhoneCtrl.text = eventMap['organizer_phone']?.toString() ?? '';
      _organizerNoteCtrl.text = eventMap['organizer_note']?.toString() ?? '';
      _isPrivate = eventMap['is_private'] == true;
      _selectedSport = eventMap['sport']?.toString() ?? _selectedSport;
      _existingCoverUrl = eventMap['image_url']?.toString();
      _flipHorizontal = eventMap['image_flip_horizontal'] == true;
      _coverFilterPreset =
          eventMap['cover_filter_preset']?.toString() ?? 'original';

      if (eventMap['start_date'] != null) {
        _startDate = DateTime.parse(eventMap['start_date'].toString());
      }
      if (eventMap['end_date'] != null) {
        _endDate = DateTime.parse(eventMap['end_date'].toString());
      }
      if (eventMap['registration_deadline'] != null) {
        _registrationDeadline =
            DateTimeUtils.fromIso(eventMap['registration_deadline'].toString());
      }

      for (final t in _pricingTiers) {
        t.dispose();
      }
      _pricingTiers.clear();
      for (final tier in PricingTierService.parseList(eventMap['pricing_tiers'])) {
        final draft = _PricingTierDraft(
          name: tier.name,
          priceText: tier.price.toStringAsFixed(
            tier.price.truncateToDouble() == tier.price ? 0 : 2,
          ),
        );
        draft.validUntil = tier.validUntil;
        _pricingTiers.add(draft);
      }
      if (_pricingTiers.isEmpty) {
        _pricingTiers.add(_PricingTierDraft(name: 'Įprasta', priceText: '20'));
      }

      _divisions.clear();
      if (tournaments.isNotEmpty) {
        final first = tournaments.first as Map<String, dynamic>;
        _maxParticipantsCtrl.text =
            first['max_participants']?.toString() ?? '16';
        _rpValueCtrl.text = first['rp_value']?.toString() ?? '1000';
        _prizeCtrl.text = first['prize_pool']?.toString() ?? '';
        _minAgeCtrl.text = first['min_age']?.toString() ?? '16';
        _maxAgeCtrl.text = first['max_age']?.toString() ?? '99';
        _minRpCtrl.text = first['min_rp']?.toString() ?? '0';
        _minXpCtrl.text = first['min_xp']?.toString() ?? '0';
      }

      for (final raw in tournaments) {
        if (raw is! Map) continue;
        final t = Map<String, dynamic>.from(raw);
        var divName = t['name']?.toString() ?? '';
        if (eventName.isNotEmpty && divName.startsWith('$eventName - ')) {
          divName = divName.replaceFirst('$eventName - ', '').trim();
        }
        Map<String, dynamic> divMeta = {};
        final divsJson = t['divisions'];
        if (divsJson is List &&
            divsJson.isNotEmpty &&
            divsJson.first is Map) {
          divMeta = Map<String, dynamic>.from(divsJson.first as Map);
        }
        _divisions.add({
          'name': divName,
          'gender': t['gender_category'] ?? divMeta['gender'] ?? 'Atvira',
          'format': t['team_format'] ?? divMeta['format'] ?? '1v1',
          'format_code': t['format_code'] ?? divMeta['format_code'] ?? '1v1',
          'min_level': divMeta['min_level'] ?? 1,
          'max_level': divMeta['max_level'] ?? 5,
          'min_level_label': divMeta['min_level_label']?.toString() ?? '',
          'max_level_label': divMeta['max_level_label']?.toString() ?? '',
        });
      }

      if (mounted) {
        setState(() => _loadingEdit = false);
        await _refreshSportEntry();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingEdit = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nepavyko užkrauti renginio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSportOptions() async {
    try {
      SportsCatalogService.invalidateCache();
      final names = await SportsCatalogService.activeSportNames();
      if (mounted && names.isNotEmpty) {
        setState(() {
          _sportOptions = names;
          if (!_sportOptions.contains(_selectedSport)) {
            _selectedSport = _sportOptions.first;
          }
        });
        await _refreshSportEntry();
        if (_rulesCtrl.text.trim().isEmpty) {
          await _loadRulesTemplate(_selectedSport, silent: true);
        }
      }
    } catch (e) {
      debugPrint("Klaida kraunant sportus: $e");
    }
  }

  Future<void> _refreshSportEntry({bool force = false}) async {
    if (force) SportsCatalogService.invalidateCache();
    _sportEntry = await SportsCatalogService.byName(_selectedSport);
    if (mounted) setState(() {});
  }

  /// DB allowed_formats + programos šablonai (jei DB dar tik 1v1).
  List<String> _formatCodesForSport() {
    final dbCodes = _sportEntry?.allowedFormats ?? [];
    final templateCodes = TeamFormatCatalog.getFormats(_selectedSport)
        .map((f) => f.code)
        .toList();

    final merged = <String>[];
    for (final code in [...dbCodes, ...templateCodes]) {
      if (!merged.contains(code)) merged.add(code);
    }
    return merged.isEmpty ? ['1v1', '2v2'] : merged;
  }

  static String _formatLabel(String code) {
    switch (code) {
      case '1v1':
        return '1v1 (Vienetai)';
      case '2v2':
        return '2v2 (Dvejetai / poros)';
      case '3x3':
        return '3x3 (Komandos)';
      case '4x4':
        return '4x4 (Komandos)';
      case '5v5':
        return '5v5 (Komandos)';
      case '6x6':
        return '6x6 (Komandos)';
      case '7v7':
        return '7v7 (Komandos)';
      case '11v11':
        return '11v11 (Komandos)';
      default:
        return code;
    }
  }

  int _minRosterForCode(String code) {
    final formats = TeamFormatCatalog.fromAllowedFormats([code]);
    if (formats.isNotEmpty && formats.first.playersOnCourt > 0) {
      return formats.first.minTeamSize;
    }
    final m = RegExp(r'^(\d+)v\d+', caseSensitive: false).firstMatch(code);
    if (m != null) return int.parse(m.group(1)!);
    return code == '1v1' ? 1 : 2;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _rulesCtrl.dispose();
    _prizeCtrl.dispose();
    _prizesInfoCtrl.dispose();
    _maxParticipantsCtrl.dispose();
    for (final t in _pricingTiers) {
      t.dispose();
    }
    _rpValueCtrl.dispose();
    _organizerCtrl.dispose();
    _organizerEmailCtrl.dispose();
    _organizerPhoneCtrl.dispose();
    _organizerNoteCtrl.dispose();
    _minAgeCtrl.dispose();
    _maxAgeCtrl.dispose();
    _minRpCtrl.dispose();
    _minXpCtrl.dispose();
    super.dispose();
  }

  bool get _hasCover =>
      _coverImageFile != null ||
      (_coverImageBytes != null && _coverImageBytes!.isNotEmpty) ||
      (_existingCoverUrl != null && _existingCoverUrl!.isNotEmpty);

  bool get _hasName => _nameCtrl.text.trim().isNotEmpty;

  bool get _hasSport =>
      _selectedSport.isNotEmpty && _sportOptions.isNotEmpty;

  bool get _canSubmitEvent =>
      _hasCover && _hasName && _hasSport && !_isLoading && !_loadingEdit;

  String? _genderCodeForDivision(Map<String, dynamic> div) {
    final raw = div['gender']?.toString();
    if (raw == null) return null;
    final low = raw.toLowerCase();
    if (low.contains('vyrai') || low.contains('men')) return 'Men';
    if (low.contains('mot') || low.contains('women')) return 'Women';
    if (low.contains('visi') || low.contains('atvira') || low.contains('mix')) {
      return 'MIX';
    }
    return null;
  }

  List<TournamentLevelInfo> _levelsForPreview() {
    final ev = _nameCtrl.text.trim();
    return _divisions.map((div) {
      final tournamentName = '$ev - ${div['name']?.toString() ?? ''}';
      final label = TournamentLevelInfo.stripEventPrefix(
        tournamentName: tournamentName,
        eventName: ev,
      );
      return TournamentLevelInfo(
        levelName: label,
        formatCode: div['format_code']?.toString() ?? '1v1',
        gender: _genderCodeForDivision(div),
        minRp: int.tryParse(_minRpCtrl.text) ?? 0,
        maxRp: 3000,
      );
    }).toList();
  }

  Future<void> _loadRulesTemplate(String sportName, {bool silent = false}) async {
    try {
      final template = await RulesTemplateService.getDefaultForSport(sportName);

      if (template == null) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Šio sporto šablono dar nėra. Įvesk taisykles rankomis.',
              ),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      setState(() {
        _rulesCtrl.text = template.content;
      });

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pridėtos $sportName taisyklės. Gali keisti pagal poreikį.',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFEAB308),
          ),
        );
      }
    } catch (e) {
      debugPrint('Rules template load fail: $e');
    }
  }

  Future<void> _onSportChanged(String? v) async {
    if (v == null) return;
    setState(() => _selectedSport = v);
    await _refreshSportEntry();
    if (_rulesCtrl.text.trim().isEmpty) {
      await _loadRulesTemplate(v, silent: true);
    }
  }

  Widget _buildRulesSection() {
    return Container(
      key: _rulesFieldKey,
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TAISYKLĖS *',
                style: GoogleFonts.oswald(
                  color: QortColors.primary,
                  fontSize: 13,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Įkelti šabloną'),
                onPressed: () => _loadRulesTemplate(_selectedSport),
                style: TextButton.styleFrom(
                  foregroundColor: QortColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rulesCtrl,
            maxLines: 10,
            style: const TextStyle(
              color: QortColors.textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
            cursorColor: QortColors.primary,
            decoration: InputDecoration(
              hintText:
                  'Įvesk turnyro taisykles arba paspausk „Įkelti šabloną“ viršuje',
              hintStyle: TextStyle(
                color: QortColors.textSecondary.withValues(alpha: 0.7),
              ),
              helperText: 'Privalomos. Dalyviai turės sutikti registracijos metu.',
              helperStyle: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
              helperMaxLines: 2,
              filled: true,
              fillColor: QortColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: QortColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: QortColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: QortColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(15),
            ),
          ),
        ],
      ),
    );
  }

  double? get _entryPrice {
    if (_pricingTiers.isEmpty) return null;
    return double.tryParse(_pricingTiers.first.priceCtrl.text);
  }

  List<PricingTier> _pricingTiersForPreview() {
    return _pricingTiers.asMap().entries.map((entry) {
      final i = entry.key;
      final d = entry.value;
      final name = d.nameCtrl.text.trim();
      return PricingTier(
        id: 'draft_$i',
        eventId: '',
        name: name.isEmpty ? (i == 0 ? 'Įprasta' : 'Pakopa ${i + 1}') : name,
        price: double.tryParse(d.priceCtrl.text) ?? 0,
        validUntil: d.validUntil,
        displayOrder: i,
      );
    }).toList();
  }

  Future<void> _addSponsorDraft() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _sponsors.add(_SponsorDraft(bytes: bytes));
    });
  }

  void _toggleMainSponsor(int idx, bool value) {
    setState(() {
      for (var i = 0; i < _sponsors.length; i++) {
        _sponsors[i] = _sponsors[i].copyWith(isMain: i == idx ? value : false);
      }
    });
  }

  List<EventSponsor> _extraSponsorsForPreview() {
    final list = _sponsors
        .where((s) => !s.isMain)
        .where((s) => s.bytes != null)
        .toList();
    return list.asMap().entries.map((e) {
      return EventSponsor(
        id: 'draft_extra_${e.key}',
        eventId: 'draft',
        logoUrl: '',
        logoBytes: e.value.bytes,
        name: e.value.name,
        sponsorLabel: e.value.sponsorLabel,
        websiteUrl: e.value.websiteUrl,
        isMain: false,
        displayOrder: e.key,
      );
    }).toList();
  }

  EventSponsor? _mainSponsorForPreview() {
    final s = _sponsors.where((s) => s.isMain).cast<_SponsorDraft?>().firstWhere(
          (e) => e?.bytes != null,
          orElse: () => null,
        );
    if (s == null || s.bytes == null) return null;
    return EventSponsor(
      id: 'draft_main',
      eventId: 'draft',
      logoUrl: '',
      logoBytes: s.bytes,
      name: s.name,
      sponsorLabel: s.sponsorLabel,
      websiteUrl: s.websiteUrl,
      isMain: true,
      displayOrder: 0,
    );
  }

  Future<void> _pickCoverImage() async {
    if (!_hasSport) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _coverImageBytes = bytes;
      if (!kIsWeb && picked.path.isNotEmpty) {
        _coverImageFile = File(picked.path);
      } else {
        _coverImageFile = null;
      }
      // New upload resets transformations
      _flipHorizontal = false;
      _coverFilterPreset = 'original';
    });
  }

  void _showCoverRequiredSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Pirma pasirink renginio vaizdą (įkelk savo nuotrauką)',
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<Uint8List> _coverBytesForUpload() async {
    if (_coverImageBytes != null) return _coverImageBytes!;
    if (_coverImageFile != null) return _coverImageFile!.readAsBytes();
    throw StateError('Nėra pasirinktos nuotraukos');
  }

  // Sponsor logo picking is handled by `_addSponsorDraft()`.

  Map<String, dynamic> _coverFieldsForInsert(String? imageUrl) => {
        if (imageUrl != null) 'image_url': imageUrl,
        'cover_source': 'organizer_upload',
        'image_flip_horizontal': _flipHorizontal,
        'cover_filter_preset': _coverFilterPreset,
      };

  Future<String?> _uploadImage(
    String id,
    Uint8List bytes,
    String ext,
    String prefix,
  ) async {
    try {
      final fileName =
          '${prefix}_${id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage
          .from('tournament-images')
          .uploadBinary(fileName, bytes);
      return Supabase.instance.client.storage
          .from('tournament-images')
          .getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  // Formatas renkamas kategorijoje (ne pagrindiniame renginio formoje).
  Future<void> _showAddDivisionDialog() async {
    await _refreshSportEntry(force: true);
    if (!mounted) return;

    TextEditingController nameCtrl = TextEditingController();
    final levelMin = SportLevels.minValue(_sportEntry);
    final levelMax = SportLevels.maxValue(_sportEntry);
    RangeValues currentRangeValues = RangeValues(
      levelMin.clamp(levelMin, levelMax),
      (levelMin + 1).clamp(levelMin, levelMax),
    );
    String divGender = "Tik Vyrai";
    final formatCodes = _formatCodesForSport();
    String divFormatCode = formatCodes.first;
    final levelHint = _sportEntry?.name == 'Tenisas'
        ? 'Pvz: NTRP 3.0 Open, Vyrai 2v2'
        : 'Pvz: A lyga, Light, PRO';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Text(
              "PRIDĖTI KATEGORIJĄ",
              style: GoogleFonts.bebasNeue(
                color: Colors.white,
                fontSize: 24,
                letterSpacing: 1,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Kategorijos pavadinimas",
                      hintText: levelHint,
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black45,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  const Text(
                    "KAM SKIRTA ŠI KATEGORIJA?",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: divGender,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        items:
                            [
                                  "Tik Vyrai",
                                  "Tik Moterys",
                                  "Mix (Vyras + Moteris)",
                                  "Visi (Atvira)",
                                ]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setModalState(() => divGender = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  const Text(
                    "ŽAIDIMO FORMATAS KATEGORIJOJE",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: divFormatCode,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        items: formatCodes
                            .map(
                              (code) => DropdownMenuItem(
                                value: code,
                                child: Text(_formatLabel(code)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => divFormatCode = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    _sportEntry != null && _sportEntry!.levelsConfig.isNotEmpty
                        ? "KOKIEMS ${_sportEntry!.name.toUpperCase()} LYGIAMS?"
                        : "KOKIEMS LYGIAMS?",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_sportEntry?.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _sportEntry!.description!,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        SportLevels.nameFor(
                          _sportEntry,
                          currentRangeValues.start.round(),
                        ),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        SportLevels.nameFor(
                          _sportEntry,
                          currentRangeValues.end.round(),
                        ),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: currentRangeValues,
                    min: levelMin,
                    max: levelMax,
                    divisions: (levelMax - levelMin).round().clamp(1, 20),
                    activeColor: Colors.blue,
                    inactiveColor: Colors.grey[800],
                    labels: RangeLabels(
                      SportLevels.nameFor(
                        _sportEntry,
                        currentRangeValues.start.round(),
                      ),
                      SportLevels.nameFor(
                        _sportEntry,
                        currentRangeValues.end.round(),
                      ),
                    ),
                    onChanged: (RangeValues values) {
                      setModalState(() {
                        currentRangeValues = values;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Atšaukti",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD946EF),
                ),
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() {
                    final minLv = currentRangeValues.start.round();
                    final maxLv = currentRangeValues.end.round();
                    _divisions.add({
                      'name': nameCtrl.text.trim(),
                      'gender': divGender,
                      'format': _formatLabel(divFormatCode),
                      'format_code': divFormatCode,
                      'min_level': minLv,
                      'max_level': maxLv,
                      'min_level_label': SportLevels.nameFor(_sportEntry, minLv),
                      'max_level_label': SportLevels.nameFor(_sportEntry, maxLv),
                    });
                  });
                  Navigator.pop(ctx);
                },
                child: const Text(
                  "PRIDĖTI",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createEventAndTournaments() async {
    if (_nameCtrl.text.isEmpty || _locationCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Užpildykite pavadinimą ir vietą!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_divisions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pridėkite bent vieną kategoriją!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_hasName || !_hasSport || !_hasCover) {
      _showCoverRequiredSnackBar();
      return;
    }

    final rulesText = _rulesCtrl.text.trim();
    if (rulesText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Privalu užpildyti turnyro taisykles'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      final rulesCtx = _rulesFieldKey.currentContext;
      if (rulesCtx != null) {
        await Scrollable.ensureVisible(
          rulesCtx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }
    if (rulesText.length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Taisyklės per trumpos — bent 50 simbolių'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      final rulesCtx = _rulesFieldKey.currentContext;
      if (rulesCtx != null) {
        await Scrollable.ensureVisible(
          rulesCtx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    try {
      String? mainImgUrl = _existingCoverUrl;
      if (_coverImageFile != null ||
          (_coverImageBytes != null && _coverImageBytes!.isNotEmpty)) {
        final bytes = await _coverBytesForUpload();
        final ext = _coverImageFile?.path.split('.').last.toLowerCase() ?? 'jpg';
        final safeExt =
            ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
        mainImgUrl = await _uploadImage(
          userId ?? 'draft',
          bytes,
          safeExt,
          'event',
        );
      }

      final eventPayload = {
        'name': _nameCtrl.text.trim(),
        'sport': _selectedSport,
        'location': _locationCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'rules': _rulesCtrl.text.trim(),
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'organizer': _organizerCtrl.text.trim(),
        'organizer_email': _organizerEmailCtrl.text.trim().isEmpty
            ? null
            : _organizerEmailCtrl.text.trim(),
        'organizer_phone': _organizerPhoneCtrl.text.trim().isEmpty
            ? null
            : _organizerPhoneCtrl.text.trim(),
        'sponsor': null,
        'prizes_info': _prizesInfoCtrl.text.trim(),
        'is_private': _isPrivate,
        'organizer_note': _organizerNoteCtrl.text.trim().isEmpty
            ? null
            : _organizerNoteCtrl.text.trim(),
        if (_registrationDeadline != null)
          'registration_deadline':
              DateTimeUtils.toIsoUtc(_registrationDeadline!),
        ..._coverFieldsForInsert(mainImgUrl),
      };

      late final String eventId;

      if (_isEditMode) {
        eventId = widget.editEventId!;
        await Supabase.instance.client
            .from('events')
            .update(eventPayload)
            .eq('id', eventId);

        final existingTiers = await PricingTierService.listByEvent(eventId);
        for (final tier in existingTiers) {
          await PricingTierService.remove(tier.id);
        }

        await Supabase.instance.client
            .from('tournaments')
            .delete()
            .eq('event_id', eventId);
      } else {
        final eventResponse = await Supabase.instance.client
            .from('events')
            .insert({
              ...eventPayload,
              'owner_id': userId,
              'status': 'open',
              'approval_status': EventOrganizerPolicy.approvalDraft,
              'payment_status': EventOrganizerPolicy.paymentUnpaid,
              'organizer_service_fee': EventOrganizerPolicy.serviceFeeEur,
            })
            .select()
            .single();
        eventId = eventResponse['id'].toString();
      }

      final previewTiers = _pricingTiersForPreview();
      final entryFee =
          PricingTierService.getEffectiveTier(previewTiers)?.price ?? 0.0;
      for (var i = 0; i < _pricingTiers.length; i++) {
        final tier = _pricingTiers[i];
        await PricingTierService.add(
          eventId: eventId,
          name: tier.nameCtrl.text.trim().isEmpty
              ? 'Pakopa ${i + 1}'
              : tier.nameCtrl.text.trim(),
          price: double.tryParse(tier.priceCtrl.text) ?? 0.0,
          validUntil: tier.validUntil,
          displayOrder: i,
        );
      }

      // Sponsors
      for (var i = 0; i < _sponsors.length; i++) {
        final s = _sponsors[i];
        final bytes = s.bytes;
        if (bytes == null) continue;
        final url = await _uploadImage(
          eventId,
          bytes,
          'png',
          'sponsor',
        );
        if (url == null) continue;
        await EventSponsorService.add(
          eventId: eventId,
          logoUrl: url,
          name: s.name,
          sponsorLabel: s.sponsorLabel,
          websiteUrl: s.websiteUrl,
          isMain: s.isMain,
          displayOrder: i,
        );
      }

      // sponsor_image_url legacy no longer used (event_sponsors table)

      List<Map<String, dynamic>> tournamentsToInsert = [];
      for (var div in _divisions) {
        tournamentsToInsert.add({
          'event_id': eventId,
          'owner_id': userId,
          'name': "${_nameCtrl.text.trim()} - ${div['name']}",
          'sport': _selectedSport,
          'location': _locationCtrl.text.trim(),
          'max_participants': int.tryParse(_maxParticipantsCtrl.text) ?? 16,
          'entry_fee': entryFee,
          'rp_value': int.tryParse(_rpValueCtrl.text) ?? 1000,
          'prize_pool': _prizeCtrl.text.trim(),
          'start_date': _startDate.toIso8601String(),
          'end_date': _endDate.toIso8601String(),
          'status': 'draft',
          'gender_category': div['gender'], // Išsaugome specifinę lytį
          'team_format': div['format'],
          'format_code': div['format_code']?.toString() ?? '1v1',
          'min_age': int.tryParse(_minAgeCtrl.text) ?? 0,
          'max_age': int.tryParse(_maxAgeCtrl.text) ?? 99,
          'is_private': _isPrivate,
          'min_roster_size': _minRosterForCode(
            div['format_code']?.toString() ?? '1v1',
          ),
          'min_rp': int.tryParse(_minRpCtrl.text) ?? 0,
          'max_rp': 3000,
          'min_xp': int.tryParse(_minXpCtrl.text) ?? 0,
          'divisions': [div],
          ..._coverFieldsForInsert(mainImgUrl),
          'gender': _genderCodeForDivision(div),
        });
      }

      await Supabase.instance.client
          .from('tournaments')
          .insert(tournamentsToInsert);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Renginys atnaujintas!'
                  : 'Renginys sukurtas kaip draft — peržiūrėk ir publikuok.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        if (_isEditMode) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TournamentDraftPreviewScreen(eventId: eventId),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Klaida: $e"), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.surface,
        foregroundColor: QortColors.textPrimary,
        title: Text(
          _isEditMode ? 'REDAGUOTI RENGINĮ' : 'SUKURTI RENGINĮ',
          style: GoogleFonts.bebasNeue(
            color: QortColors.textPrimary,
            fontSize: 24,
            letterSpacing: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: QortColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingEdit)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(color: Color(0xFFEAB308)),
              ),
            _buildSectionTitle("PAGRINDINĖ INFORMACIJA"),
            _buildTextField(
              _nameCtrl,
              "Renginio pavadinimas (pvz: Pavasario Taurė)",
              icon: LucideIcons.trophy,
              help: QortFormHelpTexts.createEventName,
              onChanged: (_) => setState(() {}),
            ),
            _buildDropdown(
              "Sporto šaka",
              _selectedSport,
              _sportOptions,
              (v) => _onSportChanged(v),
              help: QortFormHelpTexts.createSport,
            ),
            const SizedBox(height: 20),
            _buildSectionTitle("RENGINIO VIZUALAS"),
            TournamentComposerPreview(
              composer: _buildEventCoverSection(),
              sponsorBand: TournamentSponsorBand(
                compact: false,
                mainSponsor: _mainSponsorForPreview(),
                extraSponsors: _extraSponsorsForPreview(),
              ),
            ),
            const SizedBox(height: 30),
            if (_formatCodesForSport().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  "Galimi formatai: ${_formatCodesForSport().map(_formatLabel).join(', ')}. "
                  "Pasirinkite formatą skiltyje „Pridėti kategoriją“ → „Žaidimo formatas kategorijoje“.",
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                ),
              ),
            _buildTextField(
              _locationCtrl,
              "Miestas / Vieta",
              icon: LucideIcons.mapPin,
              help: QortFormHelpTexts.createLocation,
              onChanged: (_) => setState(() {}),
            ),
            _buildTextField(
              _descriptionCtrl,
              "Aprašymas (Neprivaloma)",
              icon: LucideIcons.alignLeft,
              maxLines: 4,
              help: QortFormHelpTexts.createDescription,
            ),
            _buildRulesSection(),

            const SizedBox(height: 25),
            _buildSectionTitle("REIKALAVIMAI VISIEMS LYGIAMS"),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _minAgeCtrl,
                    "Minimalus amžius",
                    isNumber: true,
                    icon: LucideIcons.userMinus,
                    help: QortFormHelpTexts.createMinAge,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildTextField(
                    _maxAgeCtrl,
                    "Maksimalus amžius",
                    isNumber: true,
                    icon: LucideIcons.userPlus,
                    help: QortFormHelpTexts.createMaxAge,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _minRpCtrl,
                    "Min. RP",
                    isNumber: true,
                    icon: LucideIcons.award,
                    help: QortFormHelpTexts.createMinRp,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildTextField(
                    _minXpCtrl,
                    "Min. XP",
                    isNumber: true,
                    icon: LucideIcons.star,
                    help: QortFormHelpTexts.createMinXp,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                color: QortColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPrivate ? const Color(0xFFD946EF) : QortColors.border,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Uždaras renginys",
                        style: TextStyle(
                          color: QortColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _isPrivate ? "Tik su pakvietimais" : "Viešai matomas",
                        style: TextStyle(
                          color: _isPrivate
                              ? const Color(0xFFD946EF)
                              : QortColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isPrivate,
                    activeThumbColor: const Color(0xFFD946EF),
                    onChanged: (val) => setState(() => _isPrivate = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),
            _buildSectionTitle("ORGANIZATORIUS IR RĖMĖJAI"),
            _buildTextField(
              _organizerCtrl,
              "Organizatorius",
              icon: LucideIcons.building,
              help: QortFormHelpTexts.createOrganizer,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _organizerEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'El. paštas (neprivaloma)',
                hintText: 'info@klubas.lt',
                prefixIcon: const Icon(LucideIcons.mail, size: 16),
                labelStyle: const TextStyle(color: Colors.white70),
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF202025),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _organizerPhoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Telefonas (neprivaloma)',
                hintText: '+370 600 12345',
                prefixIcon: const Icon(LucideIcons.phone, size: 16),
                labelStyle: const TextStyle(color: Colors.white70),
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF202025),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            _buildTextField(
              _organizerNoteCtrl,
              "Trumpai apie renginį / pastaba administratoriui (neprivaloma)",
              icon: LucideIcons.messageSquare,
              maxLines: 3,
              help: QortFormHelpTexts.createOrganizerNote,
            ),
            _buildSponsorsSection(),

            const SizedBox(height: 25),
            _buildSectionTitle("DATOS, KAINA IR RP"),
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(
                    "Pradžios data",
                    _startDate,
                    (d) => setState(() => _startDate = d),
                    help: QortFormHelpTexts.createStartDate,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildDatePicker(
                    "Pabaigos data",
                    _endDate,
                    (d) => setState(() => _endDate = d),
                    help: QortFormHelpTexts.createEndDate,
                  ),
                ),
              ],
            ),
            _buildPricingTiersSection(),
            _buildOptionalDatePicker(
              label: 'Registracija uždaroma',
              date: _registrationDeadline,
              onSelect: (d) => setState(() => _registrationDeadline = d),
              onClear: () => setState(() => _registrationDeadline = null),
              hint: 'Tuščia = uždaryta turnyro pradžioje',
            ),
            _buildTextField(
              _maxParticipantsCtrl,
              "Max dalyvių lygiui",
              isNumber: true,
              icon: LucideIcons.users,
              help: QortFormHelpTexts.createMaxParticipants,
            ),
            _buildTextField(
              _rpValueCtrl,
              "Bendra RP Taškų vertė (Nugalėtojui 100%)",
              isNumber: true,
              icon: LucideIcons.award,
              help: QortFormHelpTexts.createRpValue,
            ),

            const SizedBox(height: 30),
            _buildSectionTitle("RENGINIO KATEGORIJOS (DIVIZIONAI)"),
            const Text(
              "Čia nustatote 1v1, 2v2, 3x3, 5v5 ir t. t. Kiekviena kategorija = atskiras turnyras.",
              style: TextStyle(color: QortColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            const Text(
              "Pavyzdys: „Moterų 2v2“ ir „Vyrų 1v1“ — du atskiri turnyrai tame pačiame renginyje.",
              style: TextStyle(color: QortColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 15),

            if (_divisions.isNotEmpty)
              Column(
                children: _divisions.map((div) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                div['name'].toString().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${div['gender']} • ${div['format']} • "
                                "${div['min_level_label']} – ${div['max_level_label']}",
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.trash2,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _divisions.remove(div)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddDivisionDialog,
                icon: const Icon(
                  LucideIcons.plus,
                  color: Color(0xFFD946EF),
                  size: 18,
                ),
                label: const Text(
                  "PRIDĖTI KATEGORIJĄ",
                  style: TextStyle(
                    color: Color(0xFFD946EF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(
                    color: const Color(0xFFD946EF).withOpacity(0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              _hasCover && _hasName && _hasSport
                  ? '✓ Galima kurti renginį'
                  : !_hasName
                      ? '⚠️ Įvesk renginio pavadinimą'
                      : !_hasSport
                          ? '⚠️ Pasirink sporto šaką'
                          : '⚠️ Pasirink renginio vaizdą',
              style: TextStyle(
                color: _canSubmitEvent ? Colors.greenAccent : Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD946EF),
                  disabledBackgroundColor: const Color(0xFF3F3F46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                onPressed: _isLoading
                    ? null
                    : (_canSubmitEvent
                        ? _createEventAndTournaments
                        : () {
                            if (!_hasCover) _showCoverRequiredSnackBar();
                          }),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isEditMode ? 'IŠSAUGOTI PAKEITIMUS' : 'SUKURTI RENGINĮ',
                        style: GoogleFonts.bebasNeue(
                          color: Colors.white,
                          fontSize: 22,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.oswald(
          color: QortColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildEventCoverSection() {
    final canPick = _hasSport;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canPick)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Pirma pasirink sporto šaką, tada vaizdą',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          ),
        if (_hasCover)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.flip, size: 20),
                    tooltip: 'Veidrodis',
                    onPressed: () => setState(() {
                      _flipHorizontal = !_flipHorizontal;
                    }),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  const SizedBox(width: 4),
                  ...TournamentCoverColorFilters.presets.entries.map((e) {
                    final key = e.key;
                    final selected = _coverFilterPreset == key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(e.value, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _coverFilterPreset = key;
                        }),
                        selectedColor:
                            const Color(0xFFD946EF).withValues(alpha: 0.25),
                        backgroundColor: Colors.black26,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color:
                              selected ? const Color(0xFFD946EF) : Colors.white24,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: TournamentComposerWidget(
            imageFile: _coverImageFile,
            imageBytes: _coverImageBytes,
            eventName: _nameCtrl.text.trim().isEmpty
                ? 'RENGINIO PAVADINIMAS'
                : _nameCtrl.text.trim(),
            sport: _selectedSport,
            location: _locationCtrl.text.trim().isEmpty
                ? null
                : _locationCtrl.text.trim(),
            startDate: _startDate,
            endDate: _endDate,
            pricingTiers: _pricingTiersForPreview(),
            description: _descriptionCtrl.text.trim().isEmpty
                ? 'Pridėk renginio aprašymą - jis bus matomas ant kortelės'
                : _descriptionCtrl.text.trim(),
            organizerName: _organizerCtrl.text.trim().isEmpty
                ? null
                : _organizerCtrl.text.trim(),
            levels: _levelsForPreview(),
            flipHorizontal: _flipHorizontal,
            colorFilterPreset: _coverFilterPreset,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canPick ? _pickCoverImage : null,
            icon: const Icon(LucideIcons.camera, size: 18),
            label: Text(
              _hasCover ? 'Keisti nuotrauką' : 'Įkelti nuotrauką',
              style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD946EF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSponsorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle("RĖMĖJAI"),
        if (_sponsors.isEmpty)
          const Text(
            'Rėmėjai neprivalomi. Pridėk logotipą jei reikia.',
            style: TextStyle(color: QortColors.textSecondary, fontSize: 12),
          ),
        const SizedBox(height: 10),
        ..._sponsors.asMap().entries.map((e) {
          final idx = e.key;
          final s = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: s.bytes == null
                          ? const Icon(LucideIcons.image, size: 18)
                          : Image.memory(s.bytes!, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            onChanged: (v) => setState(() {
                              _sponsors[idx] = s.copyWith(name: v);
                            }),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Pavadinimas (optional)',
                              hintStyle: TextStyle(color: Colors.white38),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Autocomplete<String>(
                            optionsBuilder: (value) {
                              final q = value.text.trim().toLowerCase();
                              if (q.isEmpty) return const Iterable<String>.empty();
                              return _sponsorLabelSuggestions.where(
                                (o) => o.toLowerCase().contains(q),
                              );
                            },
                            onSelected: (v) => setState(() {
                              _sponsors[idx] = s.copyWith(sponsorLabel: v);
                            }),
                            fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                              final current = s.sponsorLabel ?? '';
                              if (ctrl.text != current) {
                                ctrl.text = current;
                                ctrl.selection = TextSelection.fromPosition(
                                  TextPosition(offset: ctrl.text.length),
                                );
                              }
                              return TextField(
                                controller: ctrl,
                                focusNode: focus,
                                onChanged: (v) => setState(() {
                                  _sponsors[idx] = s.copyWith(sponsorLabel: v);
                                }),
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Tipas (pvz. Generalinis rėmėjas)',
                                  hintStyle: TextStyle(color: Colors.white38),
                                  isDense: true,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            keyboardType: TextInputType.url,
                            onChanged: (v) {
                              if (v.trim().toLowerCase().startsWith('javascript:')) {
                                return;
                              }
                              setState(() {
                                _sponsors[idx] = s.copyWith(websiteUrl: v.trim());
                              });
                            },
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Website (optional)',
                              hintText: 'pvz. https://sportland.lt',
                              hintStyle: TextStyle(color: Colors.white38),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _sponsors.removeAt(idx)),
                      icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Pagrindinis',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    Switch(
                      value: s.isMain,
                      activeThumbColor: const Color(0xFFD946EF),
                      onChanged: (v) => _toggleMainSponsor(idx, v),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _addSponsorDraft,
          icon: const Icon(LucideIcons.plus, color: Color(0xFFD946EF), size: 18),
          label: const Text(
            '+ Pridėti rėmėją',
            style: TextStyle(
              color: Color(0xFFD946EF),
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: const Color(0xFFD946EF).withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    bool isNumber = false,
    IconData? icon,
    int maxLines = 1,
    String? help,
    String? helperText,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (help != null)
            QortFieldHelpLabel(label: label, help: help)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                label,
                style: const TextStyle(
                  color: QortColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          TextField(
            controller: ctrl,
            onChanged: onChanged,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            maxLines: maxLines,
            style: const TextStyle(color: QortColors.textPrimary, fontSize: 16),
            cursorColor: QortColors.primary,
            decoration: InputDecoration(
              hintText: help == null ? null : label,
              hintStyle: const TextStyle(color: QortColors.textSecondary),
              prefixIcon: icon != null
                  ? Icon(icon, color: QortColors.textSecondary, size: 20)
                  : null,
              filled: true,
              fillColor: QortColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: QortColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: QortColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: QortColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(15),
              helperText: helperText,
              helperStyle: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
              helperMaxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged, {
    String? help,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QortColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (help != null)
            QortFieldHelpLabel(
              label: label,
              help: help,
              labelStyle: const TextStyle(
                color: QortColors.textSecondary,
                fontSize: 12,
              ),
            )
          else
            Text(label, style: const TextStyle(color: QortColors.textSecondary, fontSize: 12)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: QortColors.surface,
              style: const TextStyle(color: QortColors.textPrimary, fontSize: 16),
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(color: QortColors.textPrimary),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime date,
    Function(DateTime) onSelect, {
    String? help,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: QortColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: QortColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (help != null)
              QortFieldHelpLabel(
                label: label,
                help: help,
                labelStyle: const TextStyle(
                  color: QortColors.textSecondary,
                  fontSize: 11,
                ),
              )
            else
              Text(
                label,
                style: const TextStyle(color: QortColors.textSecondary, fontSize: 11),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  LucideIcons.calendar,
                  color: QortColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('yyyy-MM-dd').format(date),
                  style: const TextStyle(
                    color: QortColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingTiersSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QortColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KAINOS PAKOPOS',
            style: GoogleFonts.oswald(
              color: QortColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Viena pakopa = fiksuota kaina. Paskutinė pakopa be datos galioja visada.',
            style: TextStyle(color: QortColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ..._pricingTiers.asMap().entries.map((entry) {
            final idx = entry.key;
            final tier = entry.value;
            final isLast = idx == _pricingTiers.length - 1;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: QortColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: QortColors.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          tier.nameCtrl,
                          'Pavadinimas',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_pricingTiers.length > 1)
                        IconButton(
                          icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
                          onPressed: () {
                            tier.dispose();
                            setState(() => _pricingTiers.removeAt(idx));
                          },
                        ),
                    ],
                  ),
                  _buildTextField(
                    tier.priceCtrl,
                    'Kaina (€)',
                    isNumber: true,
                    icon: LucideIcons.euro,
                    onChanged: (_) => setState(() {}),
                  ),
                  _buildOptionalDatePicker(
                    label: 'Galioja iki',
                    date: tier.validUntil,
                    hint: isLast
                        ? 'Palik tuščią paskutinei pakopai'
                        : 'Pasirink datą (rekomenduojama)',
                    onSelect: (d) => setState(() {
                      tier.validUntil = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        23,
                        59,
                        59,
                      );
                    }),
                    onClear: () => setState(() => tier.validUntil = null),
                  ),
                  if (isLast)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Paskutinė pakopa — palik datą tuščią, kad galėtų visada.',
                        style: TextStyle(
                          color: QortColors.textSecondary.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  final defaultUntil = DateTime.now().add(const Duration(days: 14));
                  final newTier = _PricingTierDraft(name: 'Early Bird', priceText: '15')
                    ..validUntil = DateTime(
                      defaultUntil.year,
                      defaultUntil.month,
                      defaultUntil.day,
                      23,
                      59,
                      59,
                    );
                  if (_pricingTiers.length <= 1) {
                    _pricingTiers.insert(0, newTier);
                  } else {
                    _pricingTiers.insert(_pricingTiers.length - 1, newTier);
                  }
                });
              },
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('+ Pridėti pakopą'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalDatePicker({
    required String label,
    required DateTime? date,
    required void Function(DateTime) onSelect,
    required VoidCallback onClear,
    String? hint,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now().add(const Duration(days: 14)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFFEAB308),
                  surface: Color(0xFF1A1A1A),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: QortColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: QortColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: QortColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null
                        ? DateFormat('yyyy-MM-dd').format(date)
                        : (hint ?? 'Nepasirinkta'),
                    style: TextStyle(
                      color: date != null
                          ? QortColors.textPrimary
                          : QortColors.textSecondary,
                      fontWeight:
                          date != null ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (date != null)
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: onClear,
                tooltip: 'Išvalyti',
              ),
            const Icon(LucideIcons.calendar, color: QortColors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PricingTierDraft {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  DateTime? validUntil;

  _PricingTierDraft({String name = '', String priceText = '0'})
      : nameCtrl = TextEditingController(text: name),
        priceCtrl = TextEditingController(text: priceText);

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _SponsorDraft {
  final Uint8List? bytes;
  final String? name;
  final String? sponsorLabel;
  final String? websiteUrl;
  final bool isMain;

  const _SponsorDraft({
    this.bytes,
    this.name,
    this.sponsorLabel,
    this.websiteUrl,
    this.isMain = false,
  });

  _SponsorDraft copyWith({
    Uint8List? bytes,
    String? name,
    String? sponsorLabel,
    String? websiteUrl,
    bool? isMain,
  }) {
    return _SponsorDraft(
      bytes: bytes ?? this.bytes,
      name: name ?? this.name,
      sponsorLabel: sponsorLabel ?? this.sponsorLabel,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      isMain: isMain ?? this.isMain,
    );
  }
}
