import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Thirty days of visit counts as a filled line chart. Deliberately axis-free:
/// it answers "is this trending up" at a glance, and the KPI row above it
/// carries the exact numbers.
class VisitsSparkline extends StatelessWidget {
  const VisitsSparkline({super.key, required this.counts, this.height = 60});

  /// Oldest day first.
  final List<int> counts;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SparklinePainter(counts)),
      );
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.counts);

  final List<int> counts;

  @override
  void paint(Canvas canvas, Size size) {
    // Nothing recorded yet: a dashed baseline reads as "no data", where a flat
    // solid line would read as "zero visits every day".
    if (counts.length < 2 || counts.every((c) => c == 0)) {
      _dashedBaseline(canvas, size);
      return;
    }

    const pad = 4.0;
    final max = counts.reduce((a, b) => a > b ? a : b).toDouble();
    final step = size.width / (counts.length - 1);

    final points = <Offset>[
      for (var i = 0; i < counts.length; i++)
        Offset(
          i * step,
          size.height - pad - (counts[i] / max) * (size.height - pad * 2),
        ),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.22),
            AppColors.primary.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          colors: [AppColors.ember1, AppColors.ember3],
        ).createShader(Offset.zero & size),
    );

    // Endpoint dot marks today.
    canvas.drawCircle(points.last, 3.5, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      points.last,
      3.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.card,
    );
  }

  void _dashedBaseline(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.muted2
      ..strokeWidth = 1;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + 4).clamp(0.0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      !identical(oldDelegate.counts, counts);
}
