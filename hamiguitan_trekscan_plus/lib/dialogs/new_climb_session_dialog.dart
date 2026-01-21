import 'package:flutter/material.dart';
import '../models/climb_session.dart';
import '../services/climb_session_service.dart';

class NewClimbSessionDialog extends StatefulWidget {
  final ClimbSession?
  climbSession; // Non-null for edit mode, null for create mode

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
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a climb session name')),
      );
      return;
    }

    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a trek start date')),
      );
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
    } catch (e) {
      if (mounted) {
        final errorMsg = widget.climbSession != null
            ? 'Error updating session: $e'
            : 'Error creating session: $e';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
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
          if (_endDate == null) {
            _endDate = picked.add(const Duration(days: 3));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.climbSession != null ? 'Edit Climb' : 'Start New Climb',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Climb Name',
                  hintText: 'e.g., "Morning Trek 2025"',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.hiking),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                enabled: !_isLoading,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Add notes about this climb attempt...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTrekType,
                decoration: InputDecoration(
                  labelText: 'Trek Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: _trekTypeLabels.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: !_isLoading
                    ? (value) {
                        if (value != null) {
                          setState(() => _selectedTrekType = value);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isLoading ? null : () => _selectDate(true),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trek Start Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _startDate != null
                                  ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                  : 'Select start date',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isLoading ? null : () => _selectDate(false),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trek End Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _endDate != null
                                  ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                  : 'Select end date',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: _isLoading ? null : _createSession,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.climbSession != null ? 'Update' : 'Create',
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
