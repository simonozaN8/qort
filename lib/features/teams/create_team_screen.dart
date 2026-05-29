import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../core/services/team_name_service.dart';
import '../../core/utils/sport_icons.dart';
import '../../core/utils/team_naming_rules.dart';
import 'team_formats.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String? _selectedSport;
  int _selectedLevel = 1;

  // Formatas
  TeamFormat? _selectedFormat;
  final _customFormatCodeCtrl = TextEditingController();
  final _customPlayersOnCourtCtrl = TextEditingController();
  final _customMaxTeamSizeCtrl = TextEditingController();
  bool _isCustomFormat = false;

  // Miestas
  final _cityCtrl = TextEditingController();

  // Logotipas
  Uint8List? _logoBytes;
  String? _logoFileName;
  bool _isUploadingLogo = false;

  List<Map<String, dynamic>> _userSports = [];
  bool _isLoadingSports = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserSports();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _cityCtrl.dispose();
    _customFormatCodeCtrl.dispose();
    _customPlayersOnCourtCtrl.dispose();
    _customMaxTeamSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserSports() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final response = await Supabase.instance.client
          .from('user_sports')
          .select('sport, level')
          .eq('user_id', session.user.id);

      if (mounted) {
        setState(() {
          _userSports = List<Map<String, dynamic>>.from(response);
          _isLoadingSports = false;
          // Automatiškai pasirenkame pirmąjį sportą
          if (_userSports.isNotEmpty) {
            _selectedSport = _userSports.first['sport'];
            _selectedLevel = _userSports.first['level'] ?? 1;
          }
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant sportus: $e");
      if (mounted) setState(() => _isLoadingSports = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (mounted) {
        setState(() {
          _logoBytes = bytes;
          _logoFileName = picked.name;
        });
      }
    } catch (e) {
      debugPrint("Klaida pasirenkant logotipą: $e");
    }
  }

  Future<String?> _uploadLogo(String teamId) async {
    if (_logoBytes == null) return null;

    try {
      final extension = _logoFileName?.split('.').last ?? 'jpg';
      final path = '$teamId/logo.$extension';

      await Supabase.instance.client.storage
          .from('team-logos')
          .uploadBinary(
            path,
            _logoBytes!,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$extension',
            ),
          );

      final url = Supabase.instance.client.storage
          .from('team-logos')
          .getPublicUrl(path);

      return url;
    } catch (e) {
      debugPrint("Klaida įkeliant logotipą: $e");
      return null;
    }
  }

  String? get _formatCode =>
      _isCustomFormat
          ? _customFormatCodeCtrl.text.trim()
          : _selectedFormat?.code;

  bool get _usesParticipantNames =>
      _selectedSport != null &&
      TeamNamingRules.usesParticipantNames(_selectedSport!, _formatCode);

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (_selectedSport == null) {
      _showError("Pasirink sporto šaką");
      return;
    }
    if (!_usesParticipantNames && name.isEmpty) {
      _showError("Įvesk komandos pavadinimą");
      return;
    }
    if (!_usesParticipantNames && name.length < 2) {
      _showError("Pavadinimas per trumpas");
      return;
    }

    // Formato validacija
    TeamFormat? finalFormat = _selectedFormat;
    if (_isCustomFormat) {
      final code = _customFormatCodeCtrl.text.trim();
      final onCourt = int.tryParse(_customPlayersOnCourtCtrl.text.trim()) ?? 0;
      final maxSize = int.tryParse(_customMaxTeamSizeCtrl.text.trim()) ?? 0;

      if (code.isEmpty) {
        _showError("Įvesk formato pavadinimą (pvz. 4x4)");
        return;
      }
      if (onCourt < 1) {
        _showError("Žaidėjų aikštelėje turi būti bent 1");
        return;
      }
      if (maxSize < onCourt) {
        _showError(
          "Max komandos dydis negali būti mažesnis už žaidėjų aikštelėje",
        );
        return;
      }

      finalFormat = TeamFormat(
        code: code,
        label: code,
        playersOnCourt: onCourt,
        maxTeamSize: maxSize,
      );
    }

    if (finalFormat == null) {
      _showError("Pasirink formatą");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _showError("Reikia prisijungti");
        return;
      }

      final myId = session.user.id;
      final supabase = Supabase.instance.client;

      var teamName = name;
      if (_usesParticipantNames) {
        final profile = await supabase
            .from('profiles')
            .select('nickname, name, surname')
            .eq('id', myId)
            .single();
        teamName = name.isNotEmpty
            ? name
            : TeamNamingRules.displayNameFromProfile(
                Map<String, dynamic>.from(profile),
              );
      }

      // 1. Sukurti komandą
      final teamResp = await supabase
          .from('teams')
          .insert({
            'name': teamName,
            'sport': _selectedSport,
            'creator_id': myId,
            'level': _selectedLevel,
            'format': finalFormat.code,
            'players_on_court': finalFormat.playersOnCourt,
            'max_team_size': finalFormat.maxTeamSize,
            'city': _cityCtrl.text.trim().isEmpty
                ? null
                : _cityCtrl.text.trim(),
            'description': _descriptionCtrl.text.trim().isEmpty
                ? null
                : _descriptionCtrl.text.trim(),
          })
          .select()
          .single();

      final teamId = teamResp['id'];

      // 2. Įkelti logotipą (jei pasirinktas)
      if (_logoBytes != null) {
        setState(() => _isUploadingLogo = true);
        final logoUrl = await _uploadLogo(teamId);
        if (logoUrl != null) {
          await supabase
              .from('teams')
              .update({'logo_url': logoUrl})
              .eq('id', teamId);
        }
        if (mounted) setState(() => _isUploadingLogo = false);
      }

      // 3. Pridėti kūrėją kaip narį
      await supabase.from('team_members').insert({
        'team_id': teamId,
        'user_id': myId,
        'role': 'creator',
      });

      if (_usesParticipantNames) {
        await TeamNameService.syncTeamDisplayName(teamId);
        final updated = await supabase
            .from('teams')
            .select('name')
            .eq('id', teamId)
            .single();
        teamName = updated['name']?.toString() ?? teamName;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Komanda \"$teamName\" sukurta!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Klaida kuriant komandą: $e");
      _showError("Nepavyko sukurti komandos");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = QortColors.background;
    const accentColor = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          "SUKURTI KOMANDĄ",
          style: GoogleFonts.bebasNeue(
            color: Colors.white,
            letterSpacing: 2,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingSports
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : _userSports.isEmpty
          ? _buildNoSports()
          : _buildForm(accentColor),
    );
  }

  Widget _buildNoSports() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.alertTriangle,
              size: 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              "PASIRINK SPORTO ŠAKAS",
              style: GoogleFonts.bebasNeue(
                fontSize: 20,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Pirmiausia profilyje pasirink, kuriais sportais\nsidomite. Tada galėsi kurti komandas.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(Color accentColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pavadinimas
        _label(
          _usesParticipantNames
              ? "POROS / KOMANDOS PAVADINIMAS"
              : "KOMANDOS PAVADINIMAS",
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          maxLength: 80,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: TeamNamingRules.nameFieldHint(
              _selectedSport ?? '',
              _formatCode,
            ),
            hintStyle: const TextStyle(color: Colors.grey),
            counterStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: QortColors.surface,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
          ),
        ),
        if (_usesParticipantNames) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withOpacity(0.25)),
            ),
            child: Text(
              TeamNamingRules.infoBoxText(_selectedSport!, _formatCode),
              style: const TextStyle(
                color: QortColors.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Sporto šaka
        _label("SPORTO ŠAKA"),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _userSports.map((sport) {
            final isSelected = _selectedSport == sport['sport'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSport = sport['sport'];
                  _selectedLevel = sport['level'] ?? 1;
                  _selectedFormat = null;
                  _isCustomFormat = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withOpacity(0.2)
                      : QortColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? accentColor : QortColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SportIcons.icon(
                      sport['sport'],
                      size: 18,
                      color: isSelected
                          ? accentColor
                          : QortColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sport['sport'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : QortColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        // Logotipas
        _label("LOGOTIPAS (NEPRIVALOMA)"),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickLogo,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: QortColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _logoBytes != null ? accentColor : QortColors.border,
              ),
              image: _logoBytes != null
                  ? DecorationImage(
                      image: MemoryImage(_logoBytes!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _logoBytes == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.imagePlus, color: accentColor, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        "Pridėti logotipą",
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _logoBytes = null;
                              _logoFileName = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.x,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Miestas
        _label("MIESTAS (NEPRIVALOMA)"),
        const SizedBox(height: 8),
        TextField(
          controller: _cityCtrl,
          maxLength: 30,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "Pvz., Vilnius",
            hintStyle: const TextStyle(color: Colors.grey),
            counterStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: QortColors.surface,
            contentPadding: const EdgeInsets.all(14),
            prefixIcon: const Icon(
              LucideIcons.mapPin,
              color: Colors.grey,
              size: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // FORMATAS
        if (_selectedSport != null) ...[
          _label("FORMATAS"),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final templates = TeamFormatCatalog.getFormats(_selectedSport!);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Šablonų sąrašas
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...templates.map((format) {
                        final isSelected =
                            !_isCustomFormat &&
                            _selectedFormat?.code == format.code;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFormat = format;
                              _isCustomFormat = false;
                              if (TeamNamingRules.usesParticipantNames(
                                _selectedSport!,
                                format.code,
                              )) {
                                _nameCtrl.clear();
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentColor.withOpacity(0.2)
                                  : QortColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? accentColor
                                    : QortColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  format.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : QortColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                                if (format.description != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    format.description!,
                                    style: TextStyle(
                                      color: isSelected
                                          ? QortColors.textSecondary
                                          : Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),

                      // "Pasirinktinis" mygtukas
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCustomFormat = true;
                            _selectedFormat = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _isCustomFormat
                                ? Colors.orange.withOpacity(0.2)
                                : QortColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isCustomFormat
                                  ? Colors.orange
                                  : QortColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.settings2,
                                color: _isCustomFormat
                                    ? Colors.orange
                                    : QortColors.textSecondary,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Kitas formatas",
                                style: TextStyle(
                                  color: _isCustomFormat
                                      ? Colors.white
                                      : QortColors.textSecondary,
                                  fontWeight: _isCustomFormat
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Jei pasirinktas "Kitas formatas" - rodyti laukelius
                  if (_isCustomFormat) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: QortColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                LucideIcons.info,
                                color: Colors.orange,
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Įvesk savo formato detales",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Formato kodas
                          TextField(
                            controller: _customFormatCodeCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Formato pavadinimas",
                              labelStyle: const TextStyle(
                                color: QortColors.textSecondary,
                                fontSize: 13,
                              ),
                              hintText: "pvz. 4x4, 6x6, 8x8",
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.black26,
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Žaidėjai aikštelėje + Max komandos dydis
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customPlayersOnCourtCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "Žaidėjai aikštelėje",
                                    labelStyle: const TextStyle(
                                      color: QortColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                    hintText: "pvz. 4",
                                    hintStyle: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                    filled: true,
                                    fillColor: Colors.black26,
                                    contentPadding: const EdgeInsets.all(12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _customMaxTeamSizeCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "Max komandos dydis",
                                    labelStyle: const TextStyle(
                                      color: QortColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                    hintText: "pvz. 8",
                                    hintStyle: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                    filled: true,
                                    fillColor: Colors.black26,
                                    contentPadding: const EdgeInsets.all(12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Jei sportas neturi šablonų - leisti tik custom
                  if (templates.isEmpty && !_isCustomFormat) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Šis sportas neturi numatytų formatų. Pasirink \"Kitas formatas\" ir įvesk savo.",
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
        ],
        // Aprašymas (neprivalomas)
        _label("APRAŠYMAS (NEPRIVALOMA)"),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionCtrl,
          maxLength: 200,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Pvz., Žaidžiame šeštadieniais kieme",
            hintStyle: const TextStyle(color: Colors.grey),
            counterStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: QortColors.surface,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Info kortelė
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, color: accentColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Sukūrus komandą, automatiškai tampi jos kapitonu. Tu vienintelis galėsi kviesti narius, juos šalinti ar redaguoti komandą.",
                  style: TextStyle(
                    color: accentColor.withOpacity(0.9),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Sukurti mygtukas
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(LucideIcons.shield),
          label: Text(_isSaving ? "Kuriama..." : "SUKURTI KOMANDĄ"),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.bebasNeue(
        color: QortColors.textSecondary,
        letterSpacing: 1.5,
        fontSize: 13,
      ),
    );
  }
}
