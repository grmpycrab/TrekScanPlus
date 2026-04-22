// ignore_for_file: use_key_in_widget_constructors, deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:async';
import '../../../models/member.dart';
import '../../../theme/color.dart';
import '../services/booking_validation_service.dart';

/// Editable member card for group booking form
/// Provides form fields for all member details with real-time validation
class MemberFormCard extends StatefulWidget {
  final Member member;
  final int memberIndex;
  final bool isPrimaryContact;
  final Function(Member) onMemberUpdated;
  final Function() onRemoveMember;
  final List<String> categories;

  const MemberFormCard({
    required this.member,
    required this.memberIndex,
    required this.isPrimaryContact,
    required this.onMemberUpdated,
    required this.onRemoveMember,
    this.categories = const [
      'student',
      'senior_citizen',
      'davao_oriental_resident',
      'ocfdo',
      'outside_davao_oriental',
      'children_8_15',
      'mfsm',
    ],
  });

  @override
  State<MemberFormCard> createState() => _MemberFormCardState();
}

class _MemberFormCardState extends State<MemberFormCard> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _contactController;
  late TextEditingController _nationalityController;
  late TextEditingController _addressController;
  late String _selectedGender;
  late String _selectedCategory;
  DateTime? _selectedBirthDate;

  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.member.firstName);
    _lastNameController = TextEditingController(text: widget.member.lastName);
    _contactController = TextEditingController(
      text: widget.member.contactNumber,
    );
    _nationalityController = TextEditingController(
      text: widget.member.nationality,
    );
    _addressController = TextEditingController(text: widget.member.homeAddress);

    // Parse birth date string to DateTime
    if (widget.member.birthDate.isNotEmpty) {
      try {
        _selectedBirthDate = DateTime.parse(widget.member.birthDate);
      } catch (e) {
        _selectedBirthDate = null;
      }
    }

    // Normalize gender to lowercase to match dropdown values
    String genderValue = widget.member.gender.toLowerCase();
    _selectedGender = ['male', 'female', 'other'].contains(genderValue)
        ? genderValue
        : 'other'; // Default to 'other' if invalid
    _selectedCategory = widget.member.category;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    _nationalityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Debounced member update - prevents excessive parent rebuilds
  void _scheduleMemberUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, _updateMember);
  }

  /// Open date picker for birth date selection
  Future<void> _selectBirthDate(BuildContext context) async {
    final today = DateTime.now();
    final minDate = DateTime(today.year - 130, today.month, today.day);
    final maxDate = DateTime(today.year - 5, today.month, today.day);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? maxDate,
      firstDate: minDate,
      lastDate: maxDate,
      helpText: 'Select Birth Date',
      confirmText: 'Select',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: SharedColors.white,
              surface: SharedColors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        _selectedBirthDate = selectedDate;
      });
      _scheduleMemberUpdate();
    }
  }

  void _updateMember() {
    // Format birth date as YYYY-MM-DD
    final birthDateStr = _selectedBirthDate != null
        ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
        : '';

    final updatedMember = Member(
      id: widget.member.id,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      gender: _selectedGender,
      birthDate: birthDateStr,
      contactNumber: _contactController.text,
      nationality: _nationalityController.text,
      homeAddress: _addressController.text,
      category: _selectedCategory,
      isPrimaryContact: widget.member.isPrimaryContact,
      hasAccount: widget.member.hasAccount,
      userId: widget.member.userId,
      attachments: widget.member.attachments,
      memberStatus: widget.member.memberStatus,
      createdAt: widget.member.createdAt,
      updatedAt: widget.member.updatedAt,
    );
    widget.onMemberUpdated(updatedMember);
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'student':
        return 'Student';
      case 'senior_citizen':
        return 'Senior Citizen';
      case 'davao_oriental_resident':
        return 'Davao Oriental Resident';
      case 'ocfdo':
        return 'OCFDO Member';
      case 'outside_davao_oriental':
        return 'Outside Davao Oriental';
      case 'children_8_15':
        return 'Children (8-15)';
      case 'mfsm':
        return 'MFSM Member';
      default:
        return category;
    }
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.borderBlack26),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.borderBlack26, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      filled: true,
      fillColor: SharedColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with member number and remove button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.isPrimaryContact
                  ? 'Primary Contact'
                  : 'Member ${widget.memberIndex + 1}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            if (!widget.isPrimaryContact)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.statusRejected,
                ),
                onPressed: widget.onRemoveMember,
                tooltip: 'Remove member',
              ),
          ],
        ),
        const SizedBox(height: 20),

        // First Name & Last Name
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                decoration: _buildInputDecoration('First Name'),
                onChanged: (_) => _scheduleMemberUpdate(),
                validator: (value) =>
                    BookingValidationService.validateName(value, 'First name'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lastNameController,
                decoration: _buildInputDecoration('Last Name'),
                onChanged: (_) => _scheduleMemberUpdate(),
                validator: (value) =>
                    BookingValidationService.validateName(value, 'Last name'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Gender & Birth Date
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedGender,
                isExpanded: true,
                decoration: _buildInputDecoration('Gender'),
                items: ['male', 'female', 'other']
                    .map(
                      (g) => DropdownMenuItem(
                        value: g,
                        child: Text(
                          g[0].toUpperCase() + g.substring(1),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGender = value);
                    _scheduleMemberUpdate();
                  }
                },
                validator: (value) =>
                    BookingValidationService.validateGender(value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _selectBirthDate(context),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedBirthDate == null
                              ? AppColors.borderBlack26
                              : AppColors.primary,
                          width: _selectedBirthDate == null ? 1 : 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color: SharedColors.white,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedBirthDate != null
                                  ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
                                  : 'Birth Date',
                              style: TextStyle(
                                fontSize: 14,
                                color: _selectedBirthDate != null
                                    ? AppColors.text
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: _selectedBirthDate != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Validation error display
                  if (_selectedBirthDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Builder(
                        builder: (context) {
                          final birthDateStr =
                              '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}';
                          final error =
                              BookingValidationService.validateBirthDate(
                                birthDateStr,
                              );
                          if (error != null) {
                            return Text(
                              error,
                              style: const TextStyle(
                                color: AppColors.statusRejectedDark,
                                fontSize: 12,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Contact Number
        TextFormField(
          controller: _contactController,
          decoration: _buildInputDecoration('Contact Number'),
          keyboardType: TextInputType.phone,
          onChanged: (_) => _scheduleMemberUpdate(),
          validator: (value) =>
              BookingValidationService.validatePhoneNumber(value),
        ),
        const SizedBox(height: 14),

        // Nationality
        TextFormField(
          controller: _nationalityController,
          decoration: _buildInputDecoration('Nationality'),
          onChanged: (_) => _scheduleMemberUpdate(),
          validator: (value) =>
              BookingValidationService.validateNationality(value),
        ),
        const SizedBox(height: 14),

        // Home Address
        TextFormField(
          controller: _addressController,
          decoration: _buildInputDecoration('Home Address'),
          minLines: 2,
          maxLines: 3,
          onChanged: (_) => _scheduleMemberUpdate(),
          validator: (value) => BookingValidationService.validateAddress(value),
        ),
        const SizedBox(height: 14),

        // Category
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          isExpanded: true,
          decoration: _buildInputDecoration('Participant Category'),
          items: widget.categories
              .map(
                (cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(
                    _getCategoryDisplayName(cat),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCategory = value);
              _scheduleMemberUpdate();
            }
          },
          validator: (value) => BookingValidationService.validateCategory(
            value,
            widget.categories,
          ),
        ),
      ],
    );
  }
}
