import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/utils/sport_icons.dart';
import '../../core/utils/sport_levels.dart';

class AddSportScreen extends StatefulWidget {
  const AddSportScreen({super.key});
  @override
  State<AddSportScreen> createState() => _AddSportScreenState();
}

class _AddSportScreenState extends State<AddSportScreen> {
  List<Map<String, dynamic>> _catalog = [];
  bool _isLoading = true;
  String? _selectedSportName;
  Map<String, dynamic>? _selectedSportData;
  double _currentLevelValue = 1.0;
  String _ratingCategory = 'open';
  final TextEditingController _bioCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    try {
      final entries = await SportsCatalogService.fetchActive(force: true);
      setState(() {
        _catalog = entries.map((e) => e.toJsonMap()).toList();
        if (_catalog.isNotEmpty) {
          _selectedSportName = _catalog.first['name'];
          _selectedSportData = _catalog.first;
          _ratingCategory = _defaultCategory(_catalog.first);
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Klaida: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSport() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _selectedSportData == null) return;
    setState(() => _isLoading = true);

    try {
      final existing = await Supabase.instance.client
          .from('user_sports')
          .select('id')
          .eq('user_id', user.id)
          .eq('sport', _selectedSportName!)
          .maybeSingle();

      if (existing != null) {
        throw "Šį sportą jau esate pridėję!";
      }

      final entry = SportLevels.entryFromMap(_selectedSportData);
      final lv = _currentLevelValue.round();
      final description = SportLevels.descFor(entry, lv);

      await Supabase.instance.client.from('user_sports').insert({
        'user_id': user.id,
        'sport': _selectedSportName,
        'level': lv,
        'rating_category': _ratingCategory,
        'description': description,
        'sport_bio': _bioCtrl.text,
        'official_rp': 1000,
        'global_score': 1000,
        'matches_won': 0,
        'matches_lost': 0,
        'rp_history': [],
      });
      SportsCatalogService.invalidateCache();

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _catalog.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entry = SportLevels.entryFromMap(_selectedSportData);
    final levelMin = SportLevels.minValue(entry);
    final levelMax = SportLevels.maxValue(entry);
    if (_currentLevelValue < levelMin) _currentLevelValue = levelMin;
    if (_currentLevelValue > levelMax) _currentLevelValue = levelMax;
    final lv = _currentLevelValue.round();
    final levelTitle = SportLevels.nameFor(entry, lv);
    final levelDesc = SportLevels.descFor(entry, lv);
    final categories = _categoryList(_selectedSportData);

    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text("PRIDĖTI SPORTĄ", style: GoogleFonts.bebasNeue()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PASIRINKITE SPORTO ŠAKĄ",
              style: GoogleFonts.oswald(color: Colors.blue, fontSize: 14),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _catalog.map((s) => _sportChip(s)).toList(),
            ),
            const SizedBox(height: 30),
            Text(
              entry?.name == 'Tenisas'
                  ? "JŪSŲ NTRP LYGIS (ARBA ARTĖJANTIS)"
                  : "TAVO MEISTRIŠKUMO LYGIS",
              style: GoogleFonts.oswald(color: Colors.blue, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                levelTitle,
                style: GoogleFonts.bebasNeue(fontSize: 32, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            if (categories.length > 1) ...[
              Text(
                "REITINGO KATEGORIJA",
                style: GoogleFonts.oswald(color: Colors.blue, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories
                    .map((c) => _categoryChip(c))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  SportLevels.nameFor(entry, levelMin.round()),
                  style: const TextStyle(color: QortColors.textSecondary, fontSize: 11),
                ),
                Text(
                  SportLevels.nameFor(entry, levelMax.round()),
                  style: const TextStyle(color: QortColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            Slider(
              value: _currentLevelValue,
              min: levelMin,
              max: levelMax,
              divisions: (levelMax - levelMin).round().clamp(1, 20),
              activeColor: Colors.blue,
              label: levelTitle,
              onChanged: (val) => setState(() => _currentLevelValue = val),
            ),
            Text(
              levelDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _bioCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "TRUMPAS APRAŠYMAS",
                filled: true,
                fillColor: Colors.black54,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSport,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text("IŠSAUGOTI"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _categoryList(Map<String, dynamic>? sport) {
    if (sport == null) return ['open'];
    final raw = sport['rating_categories'];
    if (raw is! List || raw.isEmpty) return ['open'];
    return raw.map((e) => e.toString()).toList();
  }

  String _defaultCategory(Map<String, dynamic> sport) =>
      _categoryList(sport).first;

  static const _categoryLabels = {
    'open': 'Atviras',
    'vyrai': 'Vyrai',
    'moterys': 'Moterys',
    'mixed': 'Mixed',
    'senjorai': 'Senjorai',
    'jaunimas': 'Jaunimas',
  };

  Widget _categoryChip(String code) {
    final sel = _ratingCategory == code;
    final label = _categoryLabels[code] ?? code;
    return GestureDetector(
      onTap: () => setState(() => _ratingCategory = code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? Colors.blue : QortColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? Colors.blue : QortColors.navInactive),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _sportChip(Map<String, dynamic> sport) {
    bool isSel = _selectedSportName == sport['name'];
    return GestureDetector(
      onTap: () {
        final e = SportLevels.entryFromMap(sport);
        setState(() {
          _selectedSportName = sport['name'];
          _selectedSportData = sport;
          _ratingCategory = _defaultCategory(sport);
          _currentLevelValue = SportLevels.minValue(e);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? Colors.blue : QortColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SportIcons.icon(
              sport['name'],
              size: 22,
              color: isSel ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              sport['name'],
              style: TextStyle(
                color: isSel ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
