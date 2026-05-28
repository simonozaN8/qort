import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Kontroleriai
  final _nicknameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _countyCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _injuryDateCtrl = TextEditingController();
  final _vacationDateCtrl = TextEditingController();

  String _gender = "Vyras";
  String _dominantSide = "Dešinė";
  String _locationPreference = "Mano mieste";
  String _photoUrl = "";

  bool _isInjured = false;
  bool _isOnVacation = false;

  Map<String, List<String>> _availability = {};
  bool _isLoading = true;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _nicknameCtrl.text = data['nickname'] ?? "";
          _nameCtrl.text = data['name'] ?? "";
          _surnameCtrl.text = data['surname'] ?? "";
          _contactEmailCtrl.text = data['contact_email'] ?? "";
          _phoneCtrl.text = data['phone'] ?? "";
          _cityCtrl.text = data['city'] ?? "";
          _districtCtrl.text = data['district'] ?? "";
          _countyCtrl.text = data['county'] ?? "";
          _heightCtrl.text = data['height'] ?? "";
          _birthDateCtrl.text = data['birth_date'] ?? "";
          _gender = data['gender'] ?? "Vyras";
          _dominantSide = data['dominant_side'] ?? "Dešinė";
          _locationPreference = data['location_preference'] ?? "Mano mieste";
          _isInjured = data['is_injured'] ?? false;
          _isOnVacation = data['is_on_vacation'] ?? false;
          _injuryDateCtrl.text = data['injury_end_date'] ?? "";
          _vacationDateCtrl.text = data['vacation_end_date'] ?? "";
          _photoUrl = data['photo_url'] ?? "";

          if (data['availability'] != null) {
            Map<String, dynamic> rawMap = data['availability'];
            _availability = rawMap.map(
              (key, value) => MapEntry(key, List<String>.from(value)),
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SUTVARKYTA: NUOTRAUKOS ĮKĖLIMAS ---
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final Uint8List bytes = await image.readAsBytes();
      final String fileExt = image.path.split('.').last;
      // Unikalus pavadinimas, kad naršyklė "necache'intų" senos
      final String fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // 1. Keliame į 'images' (NE 'avatars')
      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      // 2. Gauname nuorodą
      final String imageUrl = Supabase.instance.client.storage
          .from('images')
          .getPublicUrl(fileName);

      // 3. Išsaugome
      await Supabase.instance.client
          .from('profiles')
          .update({'photo_url': imageUrl})
          .eq('id', user.id);

      if (mounted) {
        setState(() {
          _photoUrl = imageUrl;
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nuotrauka atnaujinta!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Upload error: $e");
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Klaida: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveData() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'nickname': _nicknameCtrl.text,
            'name': _nameCtrl.text,
            'surname': _surnameCtrl.text,
            'contact_email': _contactEmailCtrl.text,
            'phone': _phoneCtrl.text,
            'city': _cityCtrl.text,
            'district': _districtCtrl.text,
            'county': _countyCtrl.text,
            'location_preference': _locationPreference,
            'height': _heightCtrl.text,
            'birth_date': _birthDateCtrl.text,
            'gender': _gender,
            'dominant_side': _dominantSide,
            'is_injured': _isInjured,
            'injury_end_date': _injuryDateCtrl.text,
            'is_on_vacation': _isOnVacation,
            'vacation_end_date': _vacationDateCtrl.text,
            'availability': _availability,
            'photo_url': _photoUrl,
          })
          .eq('id', user!.id);

      if (!mounted) return;

      setState(() => _isLoading = false);
      await _showSuccessDialog();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Klaida: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Success",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Center(
              child: Container(
                width: 250,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: QortColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.checkCircle,
                      color: Colors.green,
                      size: 50,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "IŠSAUGOTA!",
                      style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 30,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: QortColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.background,
        title: Text(
          "ASMENINIAI DUOMENYS",
          style: GoogleFonts.bebasNeue(letterSpacing: 1, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _saveData,
            icon: const Icon(LucideIcons.save, color: Colors.blue),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- NUOTRAUKOS KEITIMAS ---
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 2),
                            color: const Color(0xFF1E293B),
                            image: _photoUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_photoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _isUploadingImage
                              ? const CircularProgressIndicator()
                              : (_photoUrl.isEmpty
                                    ? const Icon(
                                        LucideIcons.user,
                                        size: 50,
                                        color: Colors.grey,
                                      )
                                    : null),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.camera,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Keisti nuotrauką",
                    style: GoogleFonts.oswald(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _section("PAGRINDINĖ INFORMACIJA"),
            _input(_nicknameCtrl, "Slapyvardis (pvz. Simonoza)"),
            Row(
              children: [
                Expanded(child: _input(_nameCtrl, "Vardas")),
                const SizedBox(width: 10),
                Expanded(child: _input(_surnameCtrl, "Pavardė")),
              ],
            ),
            _input(
              _contactEmailCtrl,
              "El. paštas (Kontaktams)",
              icon: LucideIcons.mail,
            ),
            _input(_phoneCtrl, "Telefonas", icon: LucideIcons.phone),
            _input(
              _birthDateCtrl,
              "Gimimo data (YYYY-MM-DD)",
              icon: LucideIcons.calendar,
            ),

            const SizedBox(height: 20),
            _section("LOKACIJA"),
            _input(_cityCtrl, "Miestas"),
            Row(
              children: [
                Expanded(child: _input(_districtCtrl, "Rajonas")),
                const SizedBox(width: 10),
                Expanded(child: _input(_countyCtrl, "Apskritis")),
              ],
            ),
            _dropdown(
              "Paieškos zona",
              _locationPreference,
              ["Mano mieste", "Mano rajone", "Mano apskrityje", "Visa Lietuva"],
              (v) => setState(() => _locationPreference = v!),
            ),

            const SizedBox(height: 20),
            _section("FIZINIAI DUOMENYS"),
            _genderSelector(),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _input(_heightCtrl, "Ūgis (cm)")),
                const SizedBox(width: 10),
                Expanded(
                  child: _dropdown(
                    "Dominuojanti pusė",
                    _dominantSide,
                    ["Dešinė", "Kairė"],
                    (v) => setState(() => _dominantSide = v!),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            _section("KADA GALIU ŽAISTI?"),
            const Text(
              "Pasirinkite dienas ir laikus, kada esate pasiekiamas.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _buildDetailedAvailability(),

            const SizedBox(height: 20),
            _section("STATUSAS"),
            _statusTileWithDate(
              "Atostogų rėžimas",
              _isOnVacation,
              _vacationDateCtrl,
              (v) => setState(() => _isOnVacation = v),
            ),
            const SizedBox(height: 10),
            _statusTileWithDate(
              "Traumos rėžimas",
              _isInjured,
              _injuryDateCtrl,
              (v) => setState(() => _isInjured = v),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- UI WIDGETS ---
  Widget _buildDetailedAvailability() {
    final days = ["Pirm", "Antr", "Treč", "Ketv", "Penk", "Šeš", "Sek"];
    final timeSlots = ["Rytas (8-12)", "Diena (12-17)", "Vakaras (17-22)"];

    return Column(
      children: days.map((day) {
        final isActive = _availability.containsKey(day);
        final key = PageStorageKey(day + isActive.toString());

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: QortColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? Colors.blue : QortColors.border),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: key,
              initiallyExpanded: isActive,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
              leading: Icon(
                LucideIcons.calendar,
                color: isActive ? Colors.blue : Colors.grey,
              ),
              title: Text(
                day,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Switch(
                value: isActive,
                activeThumbColor: Colors.blue,
                onChanged: (val) {
                  setState(() {
                    if (val)
                      _availability[day] = [];
                    else
                      _availability.remove(day);
                  });
                },
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: timeSlots.map((slot) {
                      final times = _availability[day] ?? [];
                      final isSlotSelected = times.contains(slot);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSlotSelected)
                              times.remove(slot);
                            else
                              times.add(slot);
                            _availability[day] = times;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSlotSelected
                                ? Colors.blue
                                : Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSlotSelected
                                  ? Colors.blue
                                  : QortColors.border,
                            ),
                          ),
                          child: Text(
                            slot,
                            style: TextStyle(
                              color: isSlotSelected
                                  ? Colors.white
                                  : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statusTileWithDate(
    String title,
    bool value,
    TextEditingController dateCtrl,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: value ? Border.all(color: Colors.red.withOpacity(0.5)) : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: value ? Colors.red : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.red,
              ),
            ],
          ),
          if (value)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                controller: dateCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Iki kada? (YYYY-MM-DD)",
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(
                    LucideIcons.calendarClock,
                    color: Colors.red,
                  ),
                  filled: true,
                  fillColor: Colors.black54,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 15),
    child: Text(
      title,
      style: GoogleFonts.oswald(
        color: Colors.blue,
        fontSize: 14,
        letterSpacing: 1,
      ),
    ),
  );
  Widget _input(TextEditingController c, String label, {IconData? icon}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
            filled: true,
            fillColor: QortColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
  Widget _genderSelector() => Row(
    children: [
      Expanded(
        child: _genderCard("Vyras", LucideIcons.user, _gender == "Vyras"),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _genderCard(
          "Moteris",
          LucideIcons.userCheck,
          _gender == "Moteris",
        ),
      ),
    ],
  );
  Widget _genderCard(String label, IconData icon, bool isSelected) =>
      GestureDetector(
        onTap: () => setState(() => _gender = label),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.withOpacity(0.2)
                : QortColors.surface,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
  Widget _dropdown(String l, String v, List<String> i, Function(String?) c) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: QortColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: i.contains(v) ? v : i.first,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            items: i
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: c,
          ),
        ),
      );
}
