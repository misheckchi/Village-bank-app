import 'package:flutter/material.dart';
import '../utils/theme.dart';

class BarData {
  final String name;
  final double value;
  final Color color;

  BarData({required this.name, required this.value, required this.color});
}

class BankBarChart extends StatelessWidget {
  final List<BarData> data;
  final String title;

  const BankBarChart({super.key, required this.data, required this.title});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sort by value descending
    final sortedData = List<BarData>.from(data)..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sortedData.first.value > 0 ? sortedData.first.value : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const Icon(Icons.leaderboard_rounded, color: BankTheme.accentPurple, size: 16),
          ],
        ),
        const SizedBox(height: 20),
        ...sortedData.take(5).map((item) => _buildBar(context, item, maxValue)).toList(),
      ],
    );
  }

  Widget _buildBar(BuildContext context, BarData item, double maxValue) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final double percentage = item.value / maxValue;
    final String initials = _getInitials(item.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: item.color.withOpacity(0.5), width: 1),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: item.color,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.name,
                    style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                'MK ${item.value.toStringAsFixed(0)}',
                style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage.clamp(0.01, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [item.color, item.color.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    List<String> parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
