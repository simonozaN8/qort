import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import '../../core/constants/app_shell_layout.dart';
import '../../core/theme/qort_design_system.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/widgets/qort_ambient_background.dart';
import '../../core/theme/qort_theme.dart';
import '../../core/models/sport_catalog_entry.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/services/user_profile_loader.dart';
import '../../core/utils/sport_levels.dart';
import '../../core/utils/sport_icons.dart';
import 'user_model.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'status_avatar.dart';
import 'my_records_screen.dart';
import 'insights_screen.dart';
import '../teams/my_teams_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../home/social_screen.dart';
import '../leaderboard/leaderboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile user;
  final Function(UserProfile) onUserUpdate;
  final AppMode currentMode;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onUserUpdate,
    this.currentMode = AppMode.competition,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;
  String _selectedSportName = "";
  Map<String, SportCatalogEntry> _catalogBySport = {};

  @override
  void initState() {
    super.initState();
    _checkSelectedSport();
    _loadSportCatalog();
  }

  Future<void> _loadSportCatalog() async {
    try {
      final all = await SportsCatalogService.fetchActive();
      if (!mounted) return;
      setState(() {
        _catalogBySport = {for (final e in all) e.name: e};
      });
    } catch (e) {
      debugPrint("Klaida kraunant sportų katalogą: $e");
    }
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkSelectedSport();
  }

  void _checkSelectedSport() {
    if (widget.user.sportsList.isNotEmpty) {
      bool hasSelected = widget.user.sportsList.any(
        (s) => s.name == _selectedSportName,
      );
      if (!hasSelected) {
        _selectedSportName = widget.user.sportsList.first.name;
      }
    } else {
      _selectedSportName = "";
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final profile = await UserProfileLoader.loadById(widget.user.id);
      if (mounted && profile != null) {
        widget.onUserUpdate(profile);
        setState(_checkSelectedSport);
      }
    } catch (e) {
      debugPrint("Klaida atnaujinant profilį: $e");
    }
  }

  SportDetails? get _currentSport {
    if (widget.user.sportsList.isEmpty) return null;
    return widget.user.sportsList.firstWhere(
      (s) => s.name == _selectedSportName,
      orElse: () => widget.user.sportsList.first,
    );
  }

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
    );
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      final fileName =
          '${widget.user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(fileName, bytes);
      final url = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('profiles')
          .update({'photo_url': url})
          .eq('id', widget.user.id);
      widget.onUserUpdate(widget.user.copyWith(photoUrl: url));
    } catch (e) {
      debugPrint("Klaida įkeliant nuotrauką: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  SportCatalogEntry? _entryForSport(String? sportName) {
    if (sportName == null || sportName.isEmpty) return null;
    return _catalogBySport[sportName];
  }

  String _getLevelName(String sportName, int level) {
    return SportLevels.nameFor(_entryForSport(sportName), level).toUpperCase();
  }

  // =======================================================
  // MATEMATINĖ LOGIKA (Pasaulinio lygio RP)
  // =======================================================

  int _getLevelMaxRp(String sportName, int level) {
    return SportLevels.maxRpForLevel(_entryForSport(sportName), level);
  }

  int _calculateRollingRp(SportDetails sport) {
    if (sport.rpHistory.isEmpty) return sport.rp;

    int activeRpDelta = 0;
    DateTime oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    int previousRp = 1000;

    for (var entry in sport.rpHistory) {
      int entryRp = int.tryParse(entry['rp']?.toString() ?? '') ?? previousRp;
      DateTime entryDate =
          DateTime.tryParse(entry['date']?.toString() ?? '') ?? DateTime.now();
      int delta = entryRp - previousRp;

      if (entryDate.isAfter(oneYearAgo)) {
        activeRpDelta += delta;
      }
      previousRp = entryRp;
    }

    int finalRp = 1000 + activeRpDelta;
    return finalRp < 0 ? 0 : finalRp;
  }

  int _calculateGlobalRp(int localRp, int level, String sportName) {
    int maxRp = _getLevelMaxRp(sportName, level);
    return (localRp * (maxRp / 3000.0)).round();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final sport = _currentSport;

    List<Map<String, dynamic>> history = sport?.rpHistory ?? [];
    if (history.isEmpty && sport != null) {
      history = [
        {'rp': (sport.rp * 0.8).toInt(), 'event': 'Sistemos kalibracija'},
        {'rp': sport.rp, 'event': 'Dabartinis reitingas'},
      ];
    }

    int rollingRp = sport != null ? _calculateRollingRp(sport) : 0;
    int globalRp = sport != null
        ? _calculateGlobalRp(rollingRp, sport.level, sport.name)
        : 0;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: p.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.shieldAlert, color: Colors.redAccent),
            tooltip: "Admin Pultas",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminDashboardScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings, color: QortColors.textSecondary),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(user: widget.user),
                ),
              );
              if (result == true) {
                SportsCatalogService.invalidateCache();
                _loadSportCatalog();
                _refreshProfile();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          QortAmbientBackground(palette: p),
          SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: AppShellLayout.scrollBottomPadding(context),
        ),
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _uploadImage,
                    child: _isUploading
                        ? const CircleAvatar(
                            radius: 50,
                            backgroundColor: QortColors.border,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : StatusAvatar(
                            imageUrl: widget.user.photoUrl,
                            displayName: widget.user.displayName,
                            radius: 50,
                            xp: widget.user.xp,
                            winStreak: widget.user.winStreak,
                            isVerified: true,
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.camera,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              widget.user.displayName,
              style: const TextStyle(
                color: QortColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            if (widget.user.city.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.mapPin, color: QortColors.textSecondary, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    widget.user.city,
                    style: const TextStyle(
                      color: QortColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 30),

            // --- 3 MŪSŲ NAUJOS KORTELĖS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildPointsCard(
                      "EINAMASIS",
                      rollingRp.toString(),
                      "365 Dienų",
                      const Color(0xFFEAB308),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPointsCard(
                      "GLOBALUS",
                      "~$globalRp",
                      "Ekvivalentas",
                      const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPointsCard(
                      "XP",
                      widget.user.xp.toString(),
                      "Aktyvumas",
                      const Color(0xFFD946EF),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            if (widget.user.sportsList.isNotEmpty)
              SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: widget.user.sportsList.length,
                  itemBuilder: (context, index) {
                    final s = widget.user.sportsList[index];
                    final isSel = s.name == _selectedSportName;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSportName = s.name),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSel ? QortColors.primary : QortColors.surface,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isSel ? QortColors.primary : QortColors.border,
                          ),
                          boxShadow: isSel
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SportIcons.icon(
                              s.name,
                              size: 16,
                              color: isSel ? Colors.white : QortColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              s.name.toUpperCase(),
                              style: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : QortColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (sport != null) ...[
              const SizedBox(height: 25),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: QortColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: QortColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getLevelName(sport.name, sport.level),
                                style: GoogleFonts.bebasNeue(
                                  color: const Color(0xFFEAB308),
                                  fontSize: 28,
                                ),
                              ),
                              Row(
                                children: [
                                  SportIcons.icon(
                                    sport.name,
                                    size: 16,
                                    color: QortColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    sport.name,
                                    style: const TextStyle(
                                      color: QortColors.textSecondary,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: QortColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: QortColors.border),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "WIN RATE",
                                  style: GoogleFonts.oswald(
                                    color: QortColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  "${(sport.winRate * 100).toInt()}%",
                                  style: const TextStyle(
                                    color: QortColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildProfileZoneSection(context),
                      const SizedBox(height: 20),
                      const Divider(color: QortColors.border),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.trendingUp,
                            color: Color(0xFF3B82F6),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "RP PROGRESO ISTORIJA",
                            style: GoogleFonts.oswald(
                              color: QortColors.textSecondary,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _LineChartPainter(
                            data: history
                                .map(
                                  (e) =>
                                      (double.tryParse(
                                        e['rp']?.toString() ?? '1000',
                                      ) ??
                                      1000.0),
                                )
                                .toList(),
                          ),
                        ),
                      ),

                      // --- TURNYRŲ ISTORIJA (IŠKART PO GRAFIKU) ---
                      if (history.length > 1) ...[
                        const SizedBox(height: 30),
                        const Divider(color: QortColors.border),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.history,
                              color: Colors.orangeAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "TURNYRŲ REZULTATAI",
                              style: GoogleFonts.oswald(
                                color: QortColors.textSecondary,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        ..._buildHistoryList(history),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
          ),
        ],
      ),
    );
  }

  // KORTELĖS
  Widget _buildPointsCard(
    String title,
    String value,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QortColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: QortColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: QortColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // TURNYRŲ SĄRAŠAS (Saugus)
  List<Widget> _buildHistoryList(List<dynamic> history) {
    List<Widget> widgets = [];
    for (int i = history.length - 1; i >= 0; i--) {
      var entry = history[i];
      if (entry == null) continue;

      int previousRp = 1000;
      if (i > 0 && history[i - 1] != null) {
        previousRp =
            int.tryParse(history[i - 1]['rp']?.toString() ?? '1000') ?? 1000;
      }

      int currentRp =
          int.tryParse(entry['rp']?.toString() ?? '1000') ?? previousRp;
      int delta = currentRp - previousRp;
      DateTime date =
          DateTime.tryParse(entry['date']?.toString() ?? '') ?? DateTime.now();

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: QortColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: QortColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: delta >= 0
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  delta >= 0
                      ? LucideIcons.trendingUp
                      : LucideIcons.trendingDown,
                  color: delta >= 0 ? Colors.greenAccent : Colors.redAccent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['event']?.toString() ?? "Turnyras",
                      style: const TextStyle(
                        color: QortColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('yyyy-MM-dd').format(date),
                      style: const TextStyle(color: QortColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                delta >= 0 ? "+$delta RP" : "$delta RP",
                style: TextStyle(
                  color: delta >= 0 ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  /// Kompaktiškos nuorodos — ne konkuruoja su apatiniu meniu.
  Widget _buildProfileZoneSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MANO ZONA',
          style: QortTheme.sectionTitle(context.qortPalette),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: QortColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: QortColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _profileZoneRow(
                context,
                icon: LucideIcons.shield,
                iconColor: Colors.amber,
                title: 'Mano komandos',
                subtitle: 'Kurk komandas ir kviesk narius',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyTeamsScreen()),
                ),
              ),
              const Divider(height: 1, color: QortColors.border, indent: 44),
              _profileZoneRow(
                context,
                icon: LucideIcons.barChart3,
                iconColor: const Color(0xFF3B82F6),
                title: 'Įžvalgos',
                subtitle: 'Statistika ir tendencijos',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InsightsScreen()),
                ),
              ),
              const Divider(height: 1, color: QortColors.border, indent: 44),
              _profileZoneRow(
                context,
                icon: LucideIcons.history,
                iconColor: const Color(0xFF3B82F6),
                title: 'Mano rezultatai',
                subtitle: 'Turnyrai ir draugiški matčai',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyRecordsScreen()),
                ),
              ),
              const Divider(height: 1, color: QortColors.border, indent: 44),
              _profileZoneRow(
                context,
                icon: LucideIcons.award,
                iconColor: const Color(0xFFEAB308),
                title: 'Reitingai',
                subtitle: 'Lentelės pagal sportą ir miestą',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeaderboardScreen(currentMode: widget.currentMode),
                  ),
                ),
              ),
              const Divider(height: 1, color: QortColors.border, indent: 44),
              _profileZoneRow(
                context,
                icon: LucideIcons.users,
                iconColor: QortColors.textSecondary,
                title: 'Bendruomenės srautas',
                subtitle: 'Draugų ir miesto aktivumas',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SocialScreen(user: widget.user),
                  ),
                ),
              ),
              const Divider(height: 1, color: QortColors.border, indent: 44),
              _profileZoneRow(
                context,
                icon: LucideIcons.edit3,
                iconColor: QortColors.textSecondary,
                title: 'Redaguoti profilį',
                subtitle: 'Vardas, nuotrauka, miestas, sportai',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  );
                  if (result == true) _refreshProfile();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileZoneRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: QortColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: QortColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: QortColors.navInactive,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ORIGINALUS TAVO GRAFIKAS
class _LineChartPainter extends CustomPainter {
  final List<double> data;
  _LineChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintLine = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final paintDot = Paint()
      ..color = QortColors.primary
      ..style = PaintingStyle.fill;
    final paintDotRing = Paint()
      ..color = QortColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final double maxVal = data.reduce(max) * 1.05;
    final double minVal = data.reduce(min) * 0.95;
    final double range = maxVal - minVal == 0 ? 1 : maxVal - minVal;
    final double stepX = size.width / (data.length > 1 ? data.length - 1 : 1);

    final Path path = Path();
    List<Offset> points = [];

    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double y = size.height - ((data[i] - minVal) / range) * size.height;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final double prevX = points[i - 1].dx;
        final double prevY = points[i - 1].dy;
        path.cubicTo(
          prevX + (x - prevX) / 2,
          prevY,
          prevX + (x - prevX) / 2,
          y,
          x,
          y,
        );
      }
    }

    final Path gradientPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final Paint paintGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF3B82F6).withOpacity(0.2), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(gradientPath, paintGradient);
    canvas.drawPath(path, paintLine);

    for (var point in points) {
      canvas.drawCircle(point, 5, paintDot);
      canvas.drawCircle(point, 5, paintDotRing);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
