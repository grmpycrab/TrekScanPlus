import 'package:flutter/material.dart';
import '../models/climb.dart';

typedef ClimbCallback = void Function(Climb);

class ClimbCard extends StatelessWidget {
  final Climb climb;
  final VoidCallback? onTap;
  final ClimbCallback? onCancel;

  const ClimbCard({Key? key, required this.climb, this.onTap, this.onCancel})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = climb.computedStatus();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          climb.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Date: ${climb.date.toLocal().toIso8601String().split('T').first}',
            ),
            Text('Type: ${climb.type}'),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 24,
                maxHeight: 28,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'Approved'
                    ? Colors.green[100]
                    : status == 'Cancelled'
                    ? Colors.grey[200]
                    : status == 'Expired'
                    ? Colors.red[100]
                    : Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: status == 'Approved'
                      ? Colors.green[800]
                      : status == 'Cancelled'
                      ? Colors.grey[700]
                      : status == 'Expired'
                      ? Colors.red[800]
                      : Colors.orange[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (status != 'Cancelled' && status != 'Expired')
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => onCancel?.call(climb),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
