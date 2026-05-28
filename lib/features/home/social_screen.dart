import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/qort_colors.dart';
import '../profile/user_model.dart'; // Būtina UserProfile modeliui

class SocialScreen extends StatefulWidget {
  final UserProfile user; // Gauname vartotoją filtravimui

  const SocialScreen({super.key, required this.user});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  // Simuliuojame "Raw" duomenų bazės srautą (kuris turi viską)
  // Realybėje čia būtų SQL užklausa su .eq('city', user.city) ir t.t.
  final List<Map<String, dynamic>> _allFeedItems = [
    {
      "type": "match_result",
      "sport": "Tenisas",
      "city": "Vilnius",
      "user": "JonasPro",
      "avatar": "J",
      "action": "laimėjo prieš TomąK",
      "image":
          "https://images.unsplash.com/photo-1622279457486-62dcc4a431d6?q=80&w=2070&auto=format&fit=crop",
      "score": "6-4, 6-3",
      "time": DateTime.now().subtract(const Duration(minutes: 15)),
      "likes": 24,
      "liked": false,
    },
    {
      "type": "match_result",
      "sport": "Pool 8",
      "city": "Kupiškis", // Šito vilnietis neturėtų matyti
      "user": "ZigmasPool",
      "avatar": "Z",
      "action": "laimėjo turnyrą",
      "image":
          "https://images.unsplash.com/photo-1571597438372-4752b04f26b5?q=80&w=2070&auto=format&fit=crop",
      "score": "8-0",
      "time": DateTime.now().subtract(const Duration(hours: 1)),
      "likes": 5,
      "liked": false,
    },
    {
      "type": "promo",
      "sport": "All", // Matoma visiems
      "city": "Global",
      "title": "PARTNERIŲ NUOLAIDA",
      "desc": "Tik QORT nariams: -20% sporto inventoriui!",
      "image":
          "https://images.unsplash.com/photo-1517649763962-0c623066013b?q=80&w=2070&auto=format&fit=crop",
      "time": DateTime.now().subtract(const Duration(hours: 2)),
      "code": "QORT20",
    },
    {
      "type": "tournament_join",
      "sport": "Padelis",
      "city":
          "Kaunas", // Jei aš iš Vilniaus, galbūt nematau, nebent domiuosi padeliu
      "user": "LauraPadel",
      "avatar": "L",
      "action": "dalyvaus turnyre 'Kaunas Open'",
      "tournament_name": "KAUNAS OPEN 2026",
      "time": DateTime.now().subtract(const Duration(hours: 5)),
      "likes": 12,
      "liked": true,
    },
  ];

  List<Map<String, dynamic>> _filteredFeed = [];

  @override
  void initState() {
    super.initState();
    _filterFeed();
  }

  // --- ALGORITMAS: Rodyti tik tai, kas aktualu ---
  void _filterFeed() {
    final myCity = widget.user.city;
    // Gauname sąrašą sportų, kuriuos vartotojas žaidžia
    final mySports = widget.user.sportsList.map((s) => s.name).toList();

    // Jei vartotojas neturi sportų, pridedame bent vieną default, kad matytų kažką
    if (mySports.isEmpty) mySports.add("Tenisas");

    setState(() {
      _filteredFeed = _allFeedItems.where((item) {
        // 1. Visada rodyti Promo/Global
        if (item['type'] == 'promo' || item['city'] == 'Global') return true;

        // 2. Tikrinti miestą (Svarbiausia taisyklė)
        // Jei įrašas iš kito miesto -> nerodom (nebent vartotojas pasirinktų "Rodyti visą Lietuvą")
        if (item['city'] != myCity) return false;

        // 3. Tikrinti sporto šaką
        // Ar įrašo sportas yra tarp mano sportų?
        // Pvz: Jei aš žaidžiu tik Tenisą, nematau Pool-8 rezultatų tame pačiame mieste.
        bool isMySport = mySports.contains(item['sport']);

        return isMySport;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.surface,
        elevation: 0,
        centerTitle: true,
        // --- GRĮŽIMO MYGTUKAS (X) ---
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(LucideIcons.x, color: QortColors.textSecondary),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: const Text(
                "Q",
                style: TextStyle(
                  fontFamily: 'Bebas Neue',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "BENDRUOMENĖ",
              style: GoogleFonts.bebasNeue(
                fontSize: 24,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          // Filtro indikatorius (rodo miestą)
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: QortColors.navInactive),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.user.city.toUpperCase(),
                style: const TextStyle(
                  color: QortColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _filteredFeed.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredFeed.length,
              itemBuilder: (context, index) {
                final item = _filteredFeed[index];
                if (item['type'] == 'promo') return _buildPromoCard(item);
                return _buildSocialCard(item);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.radio, size: 50, color: QortColors.border),
          const SizedBox(height: 15),
          Text(
            "Jokių naujienų ${widget.user.city}",
            style: GoogleFonts.oswald(color: Colors.grey, fontSize: 18),
          ),
          const SizedBox(height: 5),
          const Text(
            "Būk pirmas sužaidęs mačą!",
            style: TextStyle(color: QortColors.navInactive, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --- 1. SOCIALINĖ KORTELĖ ---
  Widget _buildSocialCard(Map<String, dynamic> item) {
    bool isMatch = item['type'] == 'match_result';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QortColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CONTEXT HEADER (Kodėl aš tai matau?)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isMatch ? LucideIcons.trophy : LucideIcons.flag,
                  size: 12,
                  color: QortColors.navInactive,
                ),
                const SizedBox(width: 6),
                Text(
                  "${item['city'].toString().toUpperCase()} • ${item['sport'].toString().toUpperCase()}",
                  style: const TextStyle(
                    color: QortColors.navInactive,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // USER INFO
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[800],
                  radius: 18,
                  child: Text(
                    item['user'][0],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: item['user'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: " ${item['action']}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        timeago.format(item['time'], locale: 'en_short'),
                        style: const TextStyle(
                          color: QortColors.navInactive,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // MEDIA (AI BRANDED PHOTO)
          if (isMatch && item['image'] != null)
            Stack(
              alignment: Alignment.bottomLeft,
              children: [
                Image.network(
                  item['image'],
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(height: 280, color: Colors.grey[900]),
                ),
                // AI OVERLAY
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "LAIMĖTOJAS",
                            style: GoogleFonts.oswald(
                              color: const Color(0xFF22C55E),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            item['score'],
                            style: GoogleFonts.bebasNeue(
                              color: Colors.white,
                              fontSize: 38,
                            ),
                          ),
                        ],
                      ),
                      // BRANDING
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "QORT",
                            style: GoogleFonts.bebasNeue(
                              color: Colors.white,
                              fontSize: 24,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            item['city'].toString().toUpperCase(),
                            style: const TextStyle(
                              color: QortColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // ACTIONS (Tik reakcijos, jokių komentarų)
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                _reactionBtn(
                  LucideIcons.flame,
                  "${item['likes']}",
                  item['liked'],
                  Colors.orange,
                ),
                const SizedBox(width: 20),
                const Spacer(),
                const Icon(LucideIcons.share2, color: QortColors.textSecondary, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. REKLAMINĖ KORTELĖ ---
  Widget _buildPromoCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1065), QortColors.background],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            item['image'],
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(height: 140, color: Colors.grey[900]),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD946EF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item['title'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      "Partnerių turinys",
                      style: TextStyle(color: QortColors.navInactive, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item['desc'],
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: QortColors.navInactive,
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "KODAS: ${item['code']}",
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFFD946EF),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reactionBtn(IconData icon, String text, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? color : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(icon, color: isActive ? color : Colors.grey, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: isActive ? color : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
