// ignore_for_file: use_key_in_widget_constructors, deprecated_member_use

import 'package:flutter/material.dart';
import '../../models/member.dart';

/// Editable member card for group booking form
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
  late TextEditingController _birthDateController;
  late TextEditingController _contactController;
  late TextEditingController _nationalityController;
  late TextEditingController _addressController;
  late String _selectedGender;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.member.firstName);
    _lastNameController = TextEditingController(text: widget.member.lastName);
    _birthDateController = TextEditingController(text: widget.member.birthDate);
    _contactController = TextEditingController(
      text: widget.member.contactNumber,
    );
    _nationalityController = TextEditingController(
      text: widget.member.nationality,
    );
    _addressController = TextEditingController(text: widget.member.homeAddress);
    // Normalize gender to lowercase to match dropdown values
    String genderValue = widget.member.gender.toLowerCase();
    _selectedGender = ['male', 'female', 'other'].contains(genderValue)
        ? genderValue
        : 'other'; // Default to 'other' if invalid
    _selectedCategory = widget.member.category;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _contactController.dispose();
    _nationalityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _updateMember() {
    final updatedMember = Member(
      id: widget.member.id,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      gender: _selectedGender,
      birthDate: _birthDateController.text,
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                  ),
                ),
                if (!widget.isPrimaryContact)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: widget.onRemoveMember,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // First Name & Last Name
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (_) => _updateMember(),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (_) => _updateMember(),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Gender & Birth Date
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: ['male', 'female', 'other']
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text(g[0].toUpperCase() + g.substring(1)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedGender = value);
                        _updateMember();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _birthDateController,
                    decoration: InputDecoration(
                      labelText: 'Birth Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (_) => _updateMember(),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contact Number
            TextFormField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: 'Contact Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => _updateMember(),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Nationality
            TextFormField(
              controller: _nationalityController,
              decoration: InputDecoration(
                labelText: 'Nationality',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => _updateMember(),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Home Address
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Home Address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              minLines: 2,
              maxLines: 3,
              onChanged: (_) => _updateMember(),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Category
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Participant Category',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: widget.categories
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(_getCategoryDisplayName(cat)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                  _updateMember();
                }
              },
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
