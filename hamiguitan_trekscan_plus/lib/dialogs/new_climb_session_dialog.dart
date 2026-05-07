// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/climb_session.dart';
import '../services/climb_session_service.dart';
import '../theme/app_theme.dart';

/// Shows the New / Edit Climb bottom sheet and returns the created or updated
/// [ClimbSession], or null if the user dismissed it.
Future<ClimbSession?> showClimbSessionSheet(
  BuildContext context, {
  ClimbSession? existing,
}) {
  return showModalBottomSheet<ClimbSession>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NewClimbSessionDialog(climbSession: existing),
  );
}

class NewClimbSessionDialog extends StatefulWidget {
  final ClimbSession? climbSession;

  const NewClimbSessionDialog({super.key, this.climbSession});

  @override
  State<NewClimbSessionDialog> createState() => _NewClimbSessionDialogState();
}

class _NewClimbSessionDialogState extends State<NewClimbSessionDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;
  String _selectedTrekType = 'regular_trek';
  DateTime? _startDate;
  DateTime? _endDate;

  /// Inline error shown inside the sheet. Null = no error.
  String? _inlineError;

  /// True when the error is specifically an active-session conflict.
  bool _isActiveSessionConflict = false;

  final Map<String, String> _trekTypeLabels = {
    'special_trek': 'Special Trek',
    'benchmarking_trek': 'Benchmarking Trek',
    'research_trek': 'Research Trek',
    'regular_trek': 'Regular Recreational Trek',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();

    _nameController.addListener(() {
      if (_inlineError != null && !_isActiveSessionConflict) {
        setState(() => _inlineError = null);
      }
    });

    // If editing, populate fields with existing data
    if (widget.climbSession != null) {
      _nameController.text = widget.climbSession!.name;
      _descriptionController.text = widget.climbSession!.description;
      _selectedTrekType = widget.climbSession!.trekType;
      _startDate = widget.climbSession!.trekStartDate;
      _endDate = widget.climbSession!.trekEndDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    setState(() {
      _inlineError = null;
      _isActiveSessionConflict = false;
    });

    if (_nameController.text.trim().isEmpty) {
      setState(() => _inlineError = 'Please enter a session name.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.climbSession != null) {
        // Edit mode: create updated session with same ID and other immutable fields
        final updatedSession = ClimbSession(
          id: widget.climbSession!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          trekType: _selectedTrekType,
          createdAt: widget.climbSession!.createdAt,
          trekStartDate: _startDate,
          trekEndDate: _endDate,
          startedAt: widget.climbSession!.startedAt,
          completedAt: widget.climbSession!.completedAt,
          status: widget.climbSession!.status,
          visitedStations: widget.climbSession!.visitedStations,
          totalDuration: widget.climbSession!.totalDuration,
          totalDistance: widget.climbSession!.totalDistance,
        );

        await ClimbSessionService.instance.updateSession(updatedSession);

        if (mounted) {
          Navigator.pop(context, updatedSession);
        }
      } else {
        // Create mode: create new session
        final session = await ClimbSessionService.instance.createClimbSession(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          trekType: _selectedTrekType,
          trekStartDate: _startDate,
          trekEndDate: _endDate,
        );

        if (mounted) {
          Navigator.pop(context, session);
        }
      }
    } on StateError catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = e.message;
          _isActiveSessionConflict = true;
          _isLoading = false;
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = widget.climbSession != null
              ? 'Could not update session. Please try again.'
              : 'Could not create session. Please try again.';
          _isActiveSessionConflict = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now().add(Duration(days: 3))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Auto-set end date to 3 days later if not already set
          _endDate ??= picked.add(const Duration(days: 3));
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: borderColor, width: 1),
              left: BorderSide(color: borderColor, width: 1),
              right: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              // ── Handle ────────────────────────────────────────────────
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.25)
                        : Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.climbSession != null
                            ? Icons.edit_outlined
                            : Icons.hiking,
                        color: colors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.climbSession != null
                                ? 'Edit Climb'
                                : 'New Climb Session',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          ),
                          Text(
                            widget.climbSession != null
                                ? 'Update your session details'
                                : 'Plan your Mt. Hamiguitan trek',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Divider(color: borderColor, height: 24),

              // ── Form ──────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Session Name', colors),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _nameController,
                        hint: 'e.g. "Morning Trek 2026"',
                        icon: Icons.hiking,
                        isDark: isDark,
                        colors: colors,
                      ),
                      const SizedBox(height: 20),

                      _sectionLabel('Notes  (optional)', colors),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _descriptionController,
                        hint: 'Any notes about this session…',
                        icon: Icons.notes_rounded,
                        isDark: isDark,
                        colors: colors,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      _sectionLabel('Trek Type', colors),
                      const SizedBox(height: 10),
                      _buildTrekTypeChips(colors, isDark),
                      const SizedBox(height: 20),

                      _sectionLabel('Trek Dates', colors),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateTile(
                              label: 'Start Date',
                              date: _startDate,
                              onTap: () => _selectDate(true),
                              colors: colors,
                              isDark: isDark,
                              borderColor: borderColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateTile(
                              label: 'End Date',
                              date: _endDate,
                              onTap: () => _selectDate(false),
                              colors: colors,
                              isDark: isDark,
                              borderColor: borderColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ── Inline error banner ───────────────────────────
                      if (_inlineError != null) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isActiveSessionConflict
                                ? Colors.orange.withOpacity(0.12)
                                : Colors.red.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isActiveSessionConflict
                                  ? Colors.orange.withOpacity(0.5)
                                  : Colors.red.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _isActiveSessionConflict
                                    ? Icons.warning_amber_rounded
                                    : Icons.error_outline,
                                size: 18,
                                color: _isActiveSessionConflict
                                    ? Colors.orange[700]
                                    : Colors.red[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isActiveSessionConflict
                                      ? 'You already have an active climb session. '
                                            'Please complete or abandon it before starting a new one.'
                                      : _inlineError!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _isActiveSessionConflict
                                        ? Colors.orange[800]
                                        : Colors.red[800],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Actions ───────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: borderColor,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                foregroundColor: colors.textSecondary,
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _createSession,
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      widget.climbSession != null
                                          ? 'Save Changes'
                                          : 'Create Session',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, dynamic colors) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    required dynamic colors,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isLoading,
      maxLines: maxLines,
      style: TextStyle(color: colors.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textSecondary.withOpacity(0.6)),
        prefixIcon: Icon(icon, size: 20, color: colors.textSecondary),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.10)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: maxLines > 1 ? 14 : 0,
        ),
      ),
    );
  }

  Widget _buildTrekTypeChips(dynamic colors, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _trekTypeLabels.entries.map((e) {
        final selected = _selectedTrekType == e.key;
        return GestureDetector(
          onTap: _isLoading
              ? null
              : () => setState(() => _selectedTrekType = e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primary
                  : isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? colors.primary
                    : isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.10),
                width: 1.2,
              ),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : colors.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateTile({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required dynamic colors,
    required bool isDark,
    required Color borderColor,
  }) {
    final hasDate = date != null;
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: hasDate ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasDate
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Set date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                      color: hasDate ? colors.text : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
