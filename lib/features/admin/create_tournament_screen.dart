import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/event_organizer_policy.dart';
import '../../core/models/sport_catalog_entry.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/utils/sport_levels.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/widgets/qort_form_help.dart';
import '../teams/team_formats.dart';

class CreateEventScreen extends StatefulWidget {
  /// `true` = paraiška per „+“ (mokama, laukia QORT patvirtinimo).
  /// `false` = partner/admin skydelis (publikuojama iš karto).
  final bool requiresApproval;

  const CreateEventScreen({super.key, this.requiresApproval = false});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();
  final _prizeCtrl = TextEditingController();
  final _prizesInfoCtrl = TextEditingController();
  final _maxParticipantsCtrl = TextEditingController(text: "16");
  final _priceCtrl = TextEditingController(text: "20");
  final _rpValueCtrl = TextEditingController(text: "1000");
  final _organizerCtrl = TextEditingController();
  final _organizerNoteCtrl = TextEditingController();
  final _sponsorCtrl = TextEditingController();
  bool _acceptedOrganizerTerms = false;

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

  Uint8List? _imageBytes;
  String? _imageExtension;
  Uint8List? _sponsorImageBytes;
  String? _sponsorImageExtension;

  final List<Map<String, dynamic>> _divisions = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSportOptions();
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
    _priceCtrl.dispose();
    _rpValueCtrl.dispose();
    _organizerCtrl.dispose();
    _organizerNoteCtrl.dispose();
    _sponsorCtrl.dispose();
    _minAgeCtrl.dispose();
    _maxAgeCtrl.dispose();
    _minRpCtrl.dispose();
    _minXpCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isSponsor) async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        if (isSponsor) {
          _sponsorImageBytes = bytes;
          _sponsorImageExtension = pickedFile.name.split('.').last;
        } else {
          _imageBytes = bytes;
          _imageExtension = pickedFile.name.split('.').last;
        }
      });
    }
  }

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
    if (widget.requiresApproval && !_acceptedOrganizerTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Patvirtinkite, kad sutinkate su mokama paslauga ir moderacija.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
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

    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    try {
      final isSubmission = widget.requiresApproval;
      final eventResponse = await Supabase.instance.client
          .from('events')
          .insert({
            'owner_id': userId,
            'name': _nameCtrl.text.trim(),
            'sport': _selectedSport,
            'location': _locationCtrl.text.trim(),
            'description': _descriptionCtrl.text.trim(),
            'rules': _rulesCtrl.text.trim(),
            'start_date': _startDate.toIso8601String(),
            'end_date': _endDate.toIso8601String(),
            'organizer': _organizerCtrl.text.trim(),
            'sponsor': _sponsorCtrl.text.trim(),
            'prizes_info': _prizesInfoCtrl.text.trim(),
            'is_private': _isPrivate,
            'status': isSubmission ? 'pending' : 'open',
            'approval_status': isSubmission
                ? EventOrganizerPolicy.approvalPending
                : EventOrganizerPolicy.approvalApproved,
            'payment_status': isSubmission
                ? EventOrganizerPolicy.paymentUnpaid
                : EventOrganizerPolicy.paymentConfirmed,
            'organizer_service_fee': EventOrganizerPolicy.serviceFeeEur,
            'organizer_note': _organizerNoteCtrl.text.trim().isEmpty
                ? null
                : _organizerNoteCtrl.text.trim(),
          })
          .select()
          .single();

      final eventId = eventResponse['id'].toString();

      String? mainImgUrl;
      String? sponsorImgUrl;
      if (_imageBytes != null) {
        mainImgUrl = await _uploadImage(
          eventId,
          _imageBytes!,
          _imageExtension ?? 'png',
          'event',
        );
        if (mainImgUrl != null) {
          await Supabase.instance.client
              .from('events')
              .update({'image_url': mainImgUrl})
              .eq('id', eventId);
        }
      }
      if (_sponsorImageBytes != null) {
        sponsorImgUrl = await _uploadImage(
          eventId,
          _sponsorImageBytes!,
          _sponsorImageExtension ?? 'png',
          'sponsor',
        );
        if (sponsorImgUrl != null) {
          await Supabase.instance.client
              .from('events')
              .update({'sponsor_image_url': sponsorImgUrl})
              .eq('id', eventId);
        }
      }

      List<Map<String, dynamic>> tournamentsToInsert = [];
      for (var div in _divisions) {
        tournamentsToInsert.add({
          'event_id': eventId,
          'owner_id': userId,
          'name': "${_nameCtrl.text.trim()} - ${div['name']}",
          'sport': _selectedSport,
          'location': _locationCtrl.text.trim(),
          'max_participants': int.tryParse(_maxParticipantsCtrl.text) ?? 16,
          'entry_fee': double.tryParse(_priceCtrl.text) ?? 0.0,
          'rp_value': int.tryParse(_rpValueCtrl.text) ?? 1000,
          'prize_pool': _prizeCtrl.text.trim(),
          'start_date': _startDate.toIso8601String(),
          'end_date': _endDate.toIso8601String(),
          'status': isSubmission ? 'draft' : 'open',
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
          'min_xp': int.tryParse(_minXpCtrl.text) ?? 0,
          'divisions': [div],
          'image_url': mainImgUrl,
        });
      }

      await Supabase.instance.client
          .from('tournaments')
          .insert(tournamentsToInsert);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSubmission
                  ? "Paraiška išsiųsta! QORT administratorius peržiūrės renginį "
                      "(${EventOrganizerPolicy.feeLabel()} paslauga) ir susisieks."
                  : "Renginys ir visi jo turnyrai sėkmingai sukurti!",
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, true);
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
          widget.requiresApproval ? "PARAIŠKA RENGINIUI" : "SUKURTI RENGINĮ",
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
            if (widget.requiresApproval) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.euro, color: Colors.amber, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          "MOKAMA PASLAUGA · ${EventOrganizerPolicy.feeLabel()}",
                          style: GoogleFonts.bebasNeue(
                            color: Colors.amber,
                            fontSize: 18,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      EventOrganizerPolicy.submissionBannerText,
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _buildSectionTitle("RENGINIO VIZUALAS"),
            _buildImageSection(false, "Įkelti pagrindinę renginio nuotrauką"),
            const SizedBox(height: 30),

            _buildSectionTitle("PAGRINDINĖ INFORMACIJA"),
            _buildTextField(
              _nameCtrl,
              "Renginio pavadinimas (pvz: Pavasario Taurė)",
              icon: LucideIcons.trophy,
              help: QortFormHelpTexts.createEventName,
            ),
            _buildDropdown(
              "Sporto šaka",
              _selectedSport,
              _sportOptions,
              (v) async {
                setState(() => _selectedSport = v!);
                await _refreshSportEntry();
              },
              help: QortFormHelpTexts.createSport,
            ),
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
            ),
            _buildTextField(
              _descriptionCtrl,
              "Aprašymas (Neprivaloma)",
              icon: LucideIcons.alignLeft,
              maxLines: 4,
              help: QortFormHelpTexts.createDescription,
            ),
            _buildTextField(
              _rulesCtrl,
              "Taisyklės (Neprivaloma)",
              icon: LucideIcons.bookOpen,
              maxLines: 4,
              help: QortFormHelpTexts.createRules,
            ),

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
            if (widget.requiresApproval)
              _buildTextField(
                _organizerNoteCtrl,
                "Trumpai apie renginį / kontaktas administratoriui (neprivaloma)",
                icon: LucideIcons.messageSquare,
                maxLines: 3,
                help: QortFormHelpTexts.createOrganizerNote,
              ),
            _buildTextField(
              _sponsorCtrl,
              "Pagrindinis Rėmėjas",
              icon: LucideIcons.briefcase,
              help: QortFormHelpTexts.createSponsor,
            ),

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
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _priceCtrl,
                    "Kaina (€)",
                    isNumber: true,
                    icon: LucideIcons.euro,
                    help: QortFormHelpTexts.createPrice,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildTextField(
                    _maxParticipantsCtrl,
                    "Max dalyvių lygiui",
                    isNumber: true,
                    icon: LucideIcons.users,
                    help: QortFormHelpTexts.createMaxParticipants,
                  ),
                ),
              ],
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

            if (widget.requiresApproval) ...[
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _acceptedOrganizerTerms,
                onChanged: (v) => setState(() => _acceptedOrganizerTerms = v ?? false),
                activeColor: const Color(0xFFD946EF),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  EventOrganizerPolicy.termsCheckboxLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                ),
              ),
            ],
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD946EF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                onPressed: _isLoading ? null : _createEventAndTournaments,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.requiresApproval
                            ? "SIŲSTI PARAIŠKĄ"
                            : "SUKURTI RENGINĮ",
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

  Widget _buildImageSection(bool isSponsor, String title) {
    final bytes = isSponsor ? _sponsorImageBytes : _imageBytes;
    return GestureDetector(
      onTap: () => _pickImage(isSponsor),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: isSponsor ? 120 : 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              image: bytes != null
                  ? DecorationImage(
                      image: MemoryImage(bytes),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          if (bytes == null)
            Column(
              children: [
                Icon(
                  isSponsor ? LucideIcons.image : LucideIcons.camera,
                  color: const Color(0xFFD946EF),
                  size: isSponsor ? 24 : 36,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.oswald(
                    color: const Color(0xFFD946EF),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    bool isNumber = false,
    IconData? icon,
    int maxLines = 1,
    String? help,
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
}
