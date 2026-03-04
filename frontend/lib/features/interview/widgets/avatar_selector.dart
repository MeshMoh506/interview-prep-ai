// lib/features/interview/widgets/avatar_selector.dart - ULTRA COMPACT

import 'package:flutter/material.dart';

class AvatarSelector extends StatelessWidget {
  final String selectedAvatarId;
  final Function(String) onAvatarSelected;

  const AvatarSelector({
    super.key,
    required this.selectedAvatarId,
    required this.onAvatarSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final avatars = [
      {
        'id': 'professional_female',
        'name': 'Pro F',
        'icon': Icons.business_center
      },
      {
        'id': 'professional_male',
        'name': 'Pro M',
        'icon': Icons.person_outline
      },
      {'id': 'casual_female', 'name': 'Casual F', 'icon': Icons.mood},
      {
        'id': 'casual_male',
        'name': 'Casual M',
        'icon': Icons.sentiment_satisfied
      },
      {'id': 'tech_female', 'name': 'Tech F', 'icon': Icons.computer},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.2,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final isSelected = selectedAvatarId == avatar['id'];

        return InkWell(
          onTap: () => onAvatarSelected(avatar['id'] as String),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                  : (isDark ? const Color(0xFF1F2937) : Colors.white),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  avatar['icon'] as IconData,
                  size: 20,
                  color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey,
                ),
                const SizedBox(height: 2),
                Text(
                  avatar['name'] as String,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
