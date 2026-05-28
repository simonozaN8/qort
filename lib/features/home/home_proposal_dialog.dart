import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/services/match_proposal_service.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_theme.dart';

/// Masinis laiko pasiūlymas keliems varžovams (iš home ekrano).
class HomeProposalDialog {
  HomeProposalDialog._();

  static void show({
    required BuildContext context,
    required List<dynamic> matches,
    required String currentUserId,
    required VoidCallback onSubmitted,
  }) {
    final opponents = matches
        .map(
          (m) => {
            'match_id': m['id'],
            'name': m['opponent_name'],
            'tournament': m['tournament_name'],
            'selected': false,
          },
        )
        .toList();

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final locationCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: QortColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: QortColors.border),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final anySelected =
                opponents.any((o) => o['selected'] == true);
            final dateText = selectedDate == null
                ? "Pasirinkite Datą"
                : DateFormat('yyyy-MM-dd').format(selectedDate!);
            final timeText = selectedTime == null
                ? "Pasirinkite Laiką"
                : "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}";

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: QortColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "SIŪLYTI LAIKĄ",
                            style: GoogleFonts.bebasNeue(
                              fontSize: 28,
                              color: QortColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setStateModal(() {
                                final allSelected =
                                    opponents.every((o) => o['selected']);
                                for (final o in opponents) {
                                  o['selected'] = !allSelected;
                                }
                              });
                            },
                            child: const Text(
                              "Pažymėti visus",
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Pasirinkite varžovus, kuriems tiktų šis laikas:",
                        style: TextStyle(color: QortColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      ...opponents.map(
                        (o) => CheckboxListTile(
                          title: Text(
                            o['name'] as String,
                            style: const TextStyle(
                              color: QortColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            o['tournament'] as String,
                            style: const TextStyle(
                              color: QortColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          value: o['selected'] as bool?,
                          activeColor: const Color(0xFFD946EF),
                          checkColor: Colors.white,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setStateModal(() => o['selected'] = val);
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _dateTile(
                              context: context,
                              label: dateText,
                              hasValue: selectedDate != null,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(
                                    const Duration(days: 1),
                                  ),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 30),
                                  ),
                                  builder: (ctx, child) => Theme(
                                    data: QortTheme.pickerTheme(ctx),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) {
                                  setStateModal(() => selectedDate = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dateTile(
                              context: context,
                              label: timeText,
                              hasValue: selectedTime != null,
                              icon: LucideIcons.clock,
                              onTap: () {
                                _showCupertinoTimePicker(context, (time) {
                                  setStateModal(() => selectedTime = time);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: locationCtrl,
                        decoration: InputDecoration(
                          hintText: "Vieta (pvz: SEB Arena)",
                          hintStyle: const TextStyle(
                            color: QortColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: QortColors.background,
                          prefixIcon: const Icon(
                            LucideIcons.mapPin,
                            color: QortColors.textSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: QortColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: QortColors.border,
                            ),
                          ),
                        ),
                        style: const TextStyle(color: QortColors.textPrimary),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: anySelected &&
                                  selectedDate != null &&
                                  selectedTime != null
                              ? () async {
                                  final dt = DateTime(
                                    selectedDate!.year,
                                    selectedDate!.month,
                                    selectedDate!.day,
                                    selectedTime!.hour,
                                    selectedTime!.minute,
                                  );
                                  final matchIds = opponents
                                      .where((o) => o['selected'] == true)
                                      .map((o) => o['match_id'] as String)
                                      .toList();
                                  Navigator.pop(context);
                                  try {
                                    final sent =
                                        await MatchProposalService
                                            .submitBulkProposals(
                                      matchIds: matchIds,
                                      proposerId: currentUserId,
                                      dateTime: dt,
                                      location: locationCtrl.text,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Išsiųsta pasiūlymų: $sent!",
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint(
                                      "Klaida siunčiant pasiūlymą: $e",
                                    );
                                  } finally {
                                    onSubmitted();
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD946EF),
                            disabledBackgroundColor:
                                Colors.grey.withValues(alpha: 0.2),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Text(
                            anySelected
                                ? "SIŪLYTI LAIKĄ"
                                : "UŽPILDYKITE DUOMENIS",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _dateTile({
    required BuildContext context,
    required String label,
    required bool hasValue,
    required VoidCallback onTap,
    IconData icon = LucideIcons.calendar,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        decoration: BoxDecoration(
          color: QortColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: QortColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: QortColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hasValue
                      ? QortColors.textPrimary
                      : QortColors.textSecondary,
                  fontWeight:
                      hasValue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showCupertinoTimePicker(
    BuildContext context,
    void Function(TimeOfDay) onSelect,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Material(
        color: Colors.transparent,
        child: Container(
          height: 300,
          decoration: const BoxDecoration(
            color: QortColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: QortColors.border),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 70),
                    const Text(
                      "PASIRINKITE LAIKĄ",
                      style: TextStyle(
                        color: QortColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 15),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          "ATLIKTA",
                          style: TextStyle(
                            color: Color(0xFFD946EF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.light,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: QortColors.textPrimary,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime.now().copyWith(minute: 0),
                    onDateTimeChanged: (val) {
                      onSelect(TimeOfDay.fromDateTime(val));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
