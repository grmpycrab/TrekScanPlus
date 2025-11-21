import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostOptionsSheet {
  static void show({
    required BuildContext context,
    required String postUserId,
    VoidCallback? onDelete,
    VoidCallback? onReport,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == postUserId;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: [
          if (isOwner)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                onDelete?.call();
              },
              isDestructiveAction: true,
              child: const Text('Delete Post'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              onReport?.call();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.exclamationmark_shield, size: 20),
                SizedBox(width: 8),
                Text('Report Post'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
