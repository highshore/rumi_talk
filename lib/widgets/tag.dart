import 'package:flutter/material.dart';

class Tag extends StatelessWidget {
  final String label;
  final String? emoji;
  final Color color;

  const Tag({super.key, required this.label, this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null && emoji!.isNotEmpty) ...[
            Text(emoji!, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}


