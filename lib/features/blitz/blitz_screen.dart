import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/demo_flow_service.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_mode_colors.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/utils/sport_icons.dart';
import '../../core/utils/sport_visual_icon.dart';
import '../../core/widgets/qort_live_scaffold.dart';
import '../../core/widgets/qort_section_header.dart';
import '../profile/user_model.dart';
import 'lobby_screen.dart';
import 'match_result_screen.dart';

class BlitzScreen extends StatefulWidget {
  const BlitzScreen({super.key});

  @override
  State<BlitzScreen> createState() => _BlitzScreenState();
}

class _BlitzScreenState extends State<BlitzScreen> {
  int _bp = 0;
  bool _loadingBp = true;

  @override
  void initState() {
    super.initState();
    _loadBp();
  }

  Future<void> _loadBp() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loadingBp = false);
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('blitz_points')
          .eq('id', uid)
          .single();
      if (mounted) {
        setState(() {
          _bp = (row['blitz_points'] as num?)?.toInt() ?? 0;
          _loadingBp = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBp = false);
    }
  }

  Future<void> _runBlitzDemo() async {
    if (!kDebugMode) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final result = await DemoFlowService.simulateBlitzWin(userId: uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.ok ? Colors.green : Colors.red,
      ),
    );
    if (result.ok) {
      await _loadBp();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MatchResultScreen(
            earnedXP: 20,
            isWin: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    const accent = QortModeColors.blitz;

    return QortLiveScaffold(
      mode: AppMode.blitz,
      title: 'Blitz',
      heroHeadline: 'Greitas formatas',
      subtitle: _loadingBp ? 'Kraunama…' : '$_bp Blitz taškų',
      onRefresh: _loadBp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _actionTile(
                  p,
                  label: 'Sukurti lobby',
                  icon: LucideIcons.plusCircle,
                  accent: accent,
                  onTap: () => _showCreateOptions(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionTile(
                  p,
                  label: 'Prisijungti',
                  icon: LucideIcons.qrCode,
                  accent: p.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LobbyScreen(isHost: false),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _runBlitzDemo,
              icon: const Icon(LucideIcons.flaskConical, size: 16),
              label: const Text('Demo: simuliuoti mačą'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.4)),
              ),
            ),
          ],
          const SizedBox(height: 20),
          QortSectionHeader(
            title: 'Aktyvūs objektai',
            accent: accent,
            icon: LucideIcons.mapPin,
          ),
          const SizedBox(height: 10),
          _liveLocationCard(
            p,
            'Baltasis tiltas',
            'Krepšinis 3x3',
            '12 žaidėjų',
            'Laukia komandų',
            accent,
          ),
          _liveLocationCard(
            p,
            'Fabijoniškių aikštelė',
            'Padelis',
            '3 žaidėjai',
            'Reikia 1 žaidėjo',
            QortModeColors.training,
          ),
          _liveLocationCard(
            p,
            'Vingio parkas',
            'Tinklinis 2x2',
            '8 žaidėjai',
            'Draugiškas mačas',
            QortModeColors.competition,
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    dynamic p, {
    required String label,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: accent, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NAUJA FUNKCIJA: NUSTATYMŲ MODALAS ---
  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: QortColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: 500,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(
                  "KONFIGŪRACIJA",
                  style: GoogleFonts.bebasNeue(
                    color: QortColors.textPrimary,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 20),
                
                Text(
                  "PASIRINKITE SPORTĄ",
                  style: GoogleFonts.oswald(
                    color: QortColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _sportOption('KREPŠINIS', true),
                      _sportOption('PADELIS', false),
                      _sportOption('FUTBOLAS', false),
                      _sportOption('TINKLINIS', false),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                Text(
                  "KOMANDOS DYDIS",
                  style: GoogleFonts.oswald(
                    color: QortColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _sizeOption("1 vs 1", false),
                    _sizeOption("2 vs 2", false),
                    _sizeOption("3 vs 3", true), // Default
                    _sizeOption("5 vs 5", false),
                  ],
                ),

                const Spacer(),
                const Divider(color: QortColors.border),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(LucideIcons.info, color: QortColors.textSecondary, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "AI automatiškai subalansuos komandas pagal žaidėjų reitingą.",
                        style: TextStyle(
                          color: QortColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Atidarome Lobby su Host teisėmis
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LobbyScreen(isHost: true)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD946EF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    child: Text("SUKURTI KAMBARĮ", style: GoogleFonts.bebasNeue(fontSize: 24, color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _sportOption(String name, bool isSelected) {
    final spec = SportVisualIcon.specFor(name);
    return Container(
      margin: const EdgeInsets.only(right: 15),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: isSelected ? spec.primary.withValues(alpha: 0.15) : QortColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? spec.primary : QortColors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: spec.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SportIcons.badge(name, size: 40),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.oswald(
              color: QortColors.textPrimary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sizeOption(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? QortColors.primary : QortColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? QortColors.primary : QortColors.border,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : QortColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _liveLocationCard(
    dynamic p,
    String place,
    String sport,
    String players,
    String status,
    Color accent,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
        color: p.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          players,
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sport,
                      style: TextStyle(color: p.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LobbyScreen(isHost: false),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: BorderSide(color: accent.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Prisijungti'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}