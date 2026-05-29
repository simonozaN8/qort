import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/query_limits.dart';

/// Hibridinis vartotojų pasirinkimo laukas
///
/// Leidžia ieškoti QORT vartotojų pagal slapyvardį, vardą arba pavardę.
/// Jei nerandamas - galima pridėti svečią (paprastas tekstas).
class UserPickerField extends StatefulWidget {
  final String label;
  final String hintText;
  final void Function(String? userId, String displayName) onUserSelected;
  final String? initialName;
  final String?
  filterBySport; // Jei nurodyta - rodomi tik tos sporto šakos žaidėjai

  const UserPickerField({
    super.key,
    required this.label,
    required this.hintText,
    required this.onUserSelected,
    this.initialName,
    this.filterBySport,
  });

  @override
  State<UserPickerField> createState() => UserPickerFieldState();
}

class UserPickerFieldState extends State<UserPickerField> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showDropdown = false;

  // Pasirinktas vartotojas (jei pasirinktas)
  String? _selectedUserId;
  String? _selectedDisplayName;

  /// Priverstinai užfiksuoja įvestą tekstą kaip svečią (pvz. prieš formos validaciją).
  /// Grąžina `(userId, displayName)` — displayName tuščias, jei nieko neužfiksuota.
  (String? userId, String displayName) commitPendingText() {
    _commitGuestIfNeeded();
    return (_selectedUserId, _selectedDisplayName ?? '');
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _ctrl.text = widget.initialName!;
      _selectedDisplayName = widget.initialName;
    }
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        final dropdownWasOpen = _showDropdown;
        if (!dropdownWasOpen) {
          _commitGuestIfNeeded();
        }
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          if (!_focusNode.hasFocus && dropdownWasOpen) {
            _commitGuestIfNeeded();
          }
          setState(() => _showDropdown = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _showDropdown = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showDropdown = true;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final myId = session?.user.id;

      List<Map<String, dynamic>> results;

      if (widget.filterBySport != null) {
        // Vienoje užklausoje: profilis + sporto šaka (be visų user_id sąrašo)
        final response = await Supabase.instance.client
            .from('profiles')
            .select(
              'id, nickname, name, surname, photo_url, city, user_sports!inner(sport)',
            )
            .eq('user_sports.sport', widget.filterBySport!)
            .or(
              'nickname.ilike.%$query%,name.ilike.%$query%,surname.ilike.%$query%',
            )
            .limit(QueryLimits.profileSearch);

        results = List<Map<String, dynamic>>.from(
          response,
        ).where((u) => u['id'] != myId).toList();
      } else {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('id, nickname, name, surname, photo_url, city')
            .or(
              'nickname.ilike.%$query%,name.ilike.%$query%,surname.ilike.%$query%',
            )
            .limit(QueryLimits.profileSearch);

        results = List<Map<String, dynamic>>.from(
          response,
        ).where((u) => u['id'] != myId).toList();
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida ieškant: $e");
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _commitGuestIfNeeded() {
    final name = _ctrl.text.trim();
    if (name.length < 2) return;
    if (_selectedUserId != null) return;
    if (_selectedDisplayName == name) return;

    setState(() {
      _selectedUserId = null;
      _selectedDisplayName = name;
      _showDropdown = false;
    });

    widget.onUserSelected(null, name);
  }

  void _selectQortUser(Map<String, dynamic> user) {
    final displayName = (user['nickname'] as String?)?.isNotEmpty == true
        ? user['nickname']
        : "${user['name'] ?? ''} ${user['surname'] ?? ''}".trim();

    setState(() {
      _ctrl.text = displayName;
      _selectedUserId = user['id'];
      _selectedDisplayName = displayName;
      _showDropdown = false;
    });

    widget.onUserSelected(user['id'], displayName);
    _focusNode.unfocus();
  }

  void _selectAsGuest() {
    _commitGuestIfNeeded();
    _focusNode.unfocus();
  }

  void _clearSelection() {
    setState(() {
      _ctrl.clear();
      _selectedUserId = null;
      _selectedDisplayName = null;
      _searchResults = [];
      _showDropdown = false;
    });
    widget.onUserSelected(null, '');
  }

  Icon _prefixIcon() {
    if (_selectedUserId != null) {
      return const Icon(
        LucideIcons.userCheck,
        color: Colors.green,
        size: 20,
      );
    }
    if (_selectedDisplayName != null && _selectedDisplayName!.isNotEmpty) {
      return const Icon(
        LucideIcons.user,
        color: Colors.orange,
        size: 20,
      );
    }
    return const Icon(LucideIcons.search, color: Colors.grey, size: 20);
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF3B82F6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.bebasNeue(
            color: QortColors.textSecondary,
            letterSpacing: 1.5,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),

        // ĮVEDIMO LAUKAS
        TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          textInputAction: TextInputAction.done,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          onSubmitted: (_) => _commitGuestIfNeeded(),
          onChanged: (value) {
            if (_selectedUserId != null && value != _selectedDisplayName) {
              // Vartotojas pradeda keisti pasirinktą - atšaukiame pasirinkimą
              setState(() {
                _selectedUserId = null;
                _selectedDisplayName = null;
              });
            }
            _search(value);
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: QortColors.surface,
            contentPadding: const EdgeInsets.all(14),
            prefixIcon: _prefixIcon(),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      color: Colors.grey,
                      size: 18,
                    ),
                    onPressed: _clearSelection,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: accentColor, width: 2),
            ),
          ),
        ),

        // PASIRINKIMO STATUSAS (jei jau pasirinkta)
        if (_selectedDisplayName != null &&
            _selectedDisplayName!.isNotEmpty &&
            !_showDropdown) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                _selectedUserId != null
                    ? LucideIcons.userCheck
                    : LucideIcons.user,
                size: 14,
                color: _selectedUserId != null ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                _selectedUserId != null ? "QORT žaidėjas" : "Svečias",
                style: TextStyle(
                  color: _selectedUserId != null ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                LucideIcons.check,
                size: 12,
                color: _selectedUserId != null ? Colors.green : Colors.orange,
              ),
            ],
          ),
        ],

        // DROPDOWN SU REZULTATAIS
        if (_showDropdown) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: QortColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: QortColors.border),
            ),
            child: Column(
              children: [
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      color: accentColor,
                      strokeWidth: 2,
                    ),
                  )
                else ...[
                  // QORT VARTOTOJŲ SĄRAŠAS
                  ..._searchResults.map((user) => _buildUserTile(user)),

                  // ATSKYRIKLIS
                  if (_searchResults.isNotEmpty)
                    const Divider(color: QortColors.border, height: 1),

                  // PRIDĖTI SVEČIĄ MYGTUKAS
                  InkWell(
                    onTap: _selectAsGuest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.userPlus,
                              color: Colors.orange,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Pridėti kaip svečią",
                                  style: GoogleFonts.bebasNeue(
                                    color: Colors.white,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  '"${_ctrl.text}" – be QORT paskyros',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final nickname = user['nickname'] as String? ?? '';
    final fullName = "${user['name'] ?? ''} ${user['surname'] ?? ''}".trim();
    final city = user['city'] as String? ?? '';
    final photoUrl = user['photo_url'] as String?;

    return InkWell(
      onTap: () => _selectQortUser(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Avataras
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: QortColors.border,
                shape: BoxShape.circle,
                image: photoUrl != null && photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: photoUrl == null || photoUrl.isEmpty
                  ? const Icon(
                      LucideIcons.user,
                      color: QortColors.textSecondary,
                      size: 18,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname.isNotEmpty ? nickname : fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (fullName.isNotEmpty && nickname.isNotEmpty)
                    Text(
                      fullName,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ),
            // Miestas
            if (city.isNotEmpty)
              Text(
                city,
                style: const TextStyle(color: QortColors.textSecondary, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}
