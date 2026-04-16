import 'package:flutter/material.dart';
import '../../../models/member.dart';
import '../../../theme/color.dart';
import '../models/document_requirements.dart';

/// Widget displaying estimated pricing summary
/// Shows per-member breakdown and total estimated cost
class PriceSummaryWidget extends StatelessWidget {
  final List<Member> members;
  final double estimatedTotalPrice;
  final bool isLoading;

  const PriceSummaryWidget({
    super.key,
    required this.members,
    required this.estimatedTotalPrice,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated Pricing',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          // Show discount info for primary member
          if (members.isNotEmpty) _buildDiscountInfo(members[0].category),
          const SizedBox(height: 12),
          if (isLoading)
            SizedBox(
              height: 60,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
            )
          else
            _buildMemberPrices(),
          const Divider(height: 16),
          _buildTotalPrice(),
        ],
      ),
    );
  }

  /// Build discount information display
  Widget _buildDiscountInfo(String category) {
    final discountDescription =
        DocumentRequirements.getDiscountDescriptionForCategory(category);
    if (discountDescription == null || discountDescription.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        border: Border.all(color: Colors.green.shade600),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.discount, color: Colors.green.shade600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              discountDescription,
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual member price rows
  Widget _buildMemberPrices() {
    return Column(
      children: members.asMap().entries.map((entry) {
        final member = entry.value;

        // Base price is 3000 PHP for three days
        final basePricePerPerson = 3000.0;
        final discountPercent = _getDiscountPercent(member.category);
        final discountAmount = basePricePerPerson * (discountPercent / 100);
        final memberPrice = basePricePerPerson - discountAmount;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${member.firstName} ${member.lastName} (${member.category})',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${memberPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (discountPercent > 0)
                    Text(
                      '(${discountPercent.toStringAsFixed(0)}% off)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Build total price row
  Widget _buildTotalPrice() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total Estimated Price',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          '₱${estimatedTotalPrice.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  /// Get discount percentage for category from centralized DocumentRequirements
  double _getDiscountPercent(String category) {
    final discount = DocumentRequirements.getDiscountForCategory(category);
    return discount?.toDouble() ?? 0.0;
  }
}
