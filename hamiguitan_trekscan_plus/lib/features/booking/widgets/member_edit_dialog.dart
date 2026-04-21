import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/member.dart';
import '../../../components/member_form_card.dart';
import '../../../theme/color.dart';

/// Dialog for adding or editing a booking member
class MemberEditDialog extends StatefulWidget {
  final Member? member;
  final int memberIndex;
  final bool isPrimaryContact;
  final Function(Member) onSave;

  const MemberEditDialog({
    super.key,
    this.member,
    required this.memberIndex,
    required this.isPrimaryContact,
    required this.onSave,
  });

  @override
  State<MemberEditDialog> createState() => _MemberEditDialogState();
}

class _MemberEditDialogState extends State<MemberEditDialog> {
  late Member _editingMember;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Initialize with existing member or create a new empty one
    _editingMember =
        widget.member ??
        Member(
          firstName: '',
          lastName: '',
          gender: 'male',
          birthDate: '',
          contactNumber: '',
          nationality: '',
          homeAddress: '',
          category: 'student',
          isPrimaryContact: widget.isPrimaryContact,
          hasAccount: false,
          createdAt: Timestamp.now(),
        );
  }

  void _handleMemberUpdated(Member updatedMember) {
    setState(() {
      _editingMember = updatedMember;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.member == null ? 'Add New Member' : 'Edit Member',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),

            // Content - scrollable form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: MemberFormCard(
                    member: _editingMember,
                    memberIndex: widget.memberIndex,
                    isPrimaryContact: widget.isPrimaryContact,
                    onMemberUpdated: _handleMemberUpdated,
                    onRemoveMember: () {
                      // Not used in dialog mode
                    },
                  ),
                ),
              ),
            ),

            // Footer with buttons
            Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSave(_editingMember);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      'Save Member',
                      style: TextStyle(color: Colors.white),
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
