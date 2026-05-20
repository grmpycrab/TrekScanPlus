import 'package:flutter/material.dart';
import '../../../models/member.dart';
import '../../../services/pricing_service.dart';
import '../../../theme/app_theme.dart';
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
    final colors = context.colors;
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        border: Border.all(color: colors.primary),
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
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          // Show discount info for primary member
          if (members.isNotEmpty)
            _buildDiscountInfo(members[0].category, colors),
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
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
              ),
            )
          else
            _buildMemberPrices(colors),
          const Divider(height: 16),
          _buildTotalPrice(colors),
        ],
      ),
    );
  }

  /// Build discount information display
  Widget _buildDiscountInfo(String category, AppTheme colors) {
    final discountDescription =
        DocumentRequirements.getDiscountDescriptionForCategory(category);
    if (discountDescription == null || discountDescription.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        border: Border.all(color: colors.green700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.discount, color: colors.green700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              discountDescription,
              style: TextStyle(
                fontSize: 12,
                color: colors.green700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual member price rows
  Widget _buildMemberPrices(AppTheme colors) {
    final ps = PricingService.instance;
    return Column(
      children: members.map((member) {
        final memberPrice = ps.calculateMemberPrice(member.category);
        final discountPercent = ps.getDiscountPercent(member.category);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${member.firstName} ${member.lastName} — ${member.categoryDisplayName}',
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
                      '($discountPercent% off)',
                      style: TextStyle(fontSize: 11, color: colors.green700),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Build total price row with estimate disclaimer
  Widget _buildTotalPrice(AppTheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                color: colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Estimate only — actual payment is collected at the ranger station on trek day. No online payment is required.',
          style: TextStyle(
            fontSize: 11,
            color: colors.textTertiary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
