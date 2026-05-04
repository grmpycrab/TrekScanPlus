import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostOptionsSheet {
  static void show({
    required BuildContext context,
    required String postUserId,
    VoidCallback? onEdit,
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
                onEdit?.call();
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [SizedBox(width: 8), Text('Edit Post')],
              ),
            ),
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
              children: [SizedBox(width: 8), Text('Report Post')],
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
