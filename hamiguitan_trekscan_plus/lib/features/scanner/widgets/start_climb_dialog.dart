import 'package:flutter/material.dart';
import '../../../services/climb_session_guard.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';

/// Dialog shown when the user scans a station QR but has no active climb session.
///
/// Lets the user name the session and select a trek type, then creates it via
/// [ClimbSessionService]. Returns `true` if a session was successfully started,
/// `false` / null if the user cancelled.
class StartClimbDialog extends StatefulWidget {
  const StartClimbDialog({super.key});

  @override
  State<StartClimbDialog> createState() => _StartClimbDialogState();
}

class _StartClimbDialogState extends State<StartClimbDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _selectedTrekType = 'regular_trek';
  bool _isCreating = false;
  String? _error;

  static const _trekTypes = [
    _TrekTypeOption('regular_trek', 'Regular Trek', Icons.hiking),
    _TrekTypeOption('special_trek', 'Special Trek', Icons.star_outline),
    _TrekTypeOption('research_trek', 'Research Trek', Icons.science_outlined),
    _TrekTypeOption('benchmarking_trek', 'Benchmarking Trek', Icons.straighten),
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill with a date-based default name.
    final now = DateTime.now();
    _nameController.text =
        'Trek — ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _startClimb() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      await ClimbSessionGuard.instance.createSession(
        name: _nameController.text.trim(),
        trekType: _selectedTrekType,
      );
      AppLogger.i('New climb session created via ClimbSessionGuard');
      if (mounted) Navigator.of(context).pop(true);
    } on StateError catch (e) {
      // Single-session enforcement fired — already has an active session.
      setState(() {
        _error = e.message;
        _isCreating = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not create session: $e';
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.hiking, color: colors.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Start a Climb',
            style: TextStyle(
              color: colors.text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You scanned a station but have no active climb session. '
                  'Start one to record your progress.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: colors.text, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Session name',
                    labelStyle: TextStyle(color: colors.textSecondary),
                    filled: true,
                    fillColor: colors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Trek type',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _trekTypes.map((type) {
                    final selected = _selectedTrekType == type.value;
                    return ChoiceChip(
                      avatar: Icon(
                        type.icon,
                        size: 16,
                        color: selected ? Colors.white : colors.textSecondary,
                      ),
                      label: Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.white : colors.text,
                        ),
                      ),
                      selected: selected,
                      selectedColor: colors.primary,
                      backgroundColor: colors.inputFill,
                      onSelected: (_) =>
                          setState(() => _selectedTrekType = type.value),
                    );
                  }).toList(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _startClimb,
          style: FilledButton.styleFrom(backgroundColor: colors.primary),
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Start Climb'),
        ),
      ],
    );
  }
}

class _TrekTypeOption {
  final String value;
  final String label;
  final IconData icon;
  const _TrekTypeOption(this.value, this.label, this.icon);
}
