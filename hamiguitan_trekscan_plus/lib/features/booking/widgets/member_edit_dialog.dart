import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/member.dart';
import './member_form_card.dart';
import '../../../theme/app_theme.dart';

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
    final colors = context.colors;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.borderLight, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.member == null
                              ? 'Add New Member'
                              : 'Edit Member',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.member == null
                              ? 'Fill in all details to continue'
                              : 'Update member information',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: colors.textSecondary,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ],
              ),
            ),

            // Content - scrollable form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 28,
                ),
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
            Container(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colors.borderLight, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        side: BorderSide(color: colors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 14,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          widget.onSave(_editingMember);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text(
                        'Save Member',
                        style: TextStyle(
                          color: SharedColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
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
