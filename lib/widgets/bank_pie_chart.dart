import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class PieData {
  final String name;
  final double value;
  final Color color;

  PieData({required this.name, required this.value, required this.color});
}

class BankPieChart extends StatelessWidget {
  final List<PieData> data;
  final double radius;

  const BankPieChart({super.key, required this.data, this.radius = 120});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: radius * 2 + 40,
          width: radius * 2 + 40,
          child: CustomPaint(
            painter: _PiePainter(data),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: data.map((d) => _buildLegendItem(d)).toList(),
        ),
      ],
    );
  }

  Widget _buildLegendItem(PieData d) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '${_getInitials(d.name)}: MK ${d.value.toStringAsFixed(0)}',
          style: const TextStyle(color: BankTheme.textMuted, fontSize: 12),
        ),
      ],
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

class _PiePainter extends CustomPainter {
  final List<PieData> data;

  _PiePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final double total = data.fold(0, (sum, item) => sum + item.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -pi / 2;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (var item in data) {
      final sweepAngle = (item.value / total) * 2 * pi;
      
      // Draw segment
      paint.color = item.color;
      paint.style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      // Draw white border around segment for visibility
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);

      // Draw Initials on the segment
      if (item.value > 0) {
        final labelAngle = startAngle + sweepAngle / 2;
        final labelRadius = radius * 0.75;
        final labelOffset = Offset(
          center.dx + labelRadius * cos(labelAngle),
          center.dy + labelRadius * sin(labelAngle),
        );

        final initials = _getInitials(item.name);
        _drawText(canvas, initials, labelOffset);
      }

      startAngle += sweepAngle;
    }
    
    // Draw hole in middle for Donut effect - Using White for "White Chart" look
    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.45, holePaint);
    
    // Inner border for the hole
    final innerBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.45, innerBorderPaint);
  }

  void _drawText(Canvas canvas, String text, Offset position) {
    // Draw a small white circle background for initials to make them very visible
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(position, 10, bgPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black, // Black text on white circle
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    List<String> parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
