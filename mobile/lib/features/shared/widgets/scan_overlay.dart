import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The viewfinder chrome drawn over a live camera: everything outside the scan
/// window dimmed, corner brackets, and a travelling scan line.
///
/// Shared by the customer's check-in scanner and the owner's shop-registration
/// scanner so both read as the same instrument.
class ScanOverlay extends StatefulWidget {
  const ScanOverlay({super.key, required this.scanSize});

  final double scanSize;

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _CutoutPainter(scanSize: widget.scanSize)),
          Center(
            child: SizedBox(
              width: widget.scanSize,
              height: widget.scanSize,
              child: Stack(
                children: [
                  for (final corner in const [
                    Alignment.topLeft,
                    Alignment.topRight,
                    Alignment.bottomLeft,
                    Alignment.bottomRight,
                  ])
                    Align(alignment: corner, child: _Corner(alignment: corner)),
                  AnimatedBuilder(
                    animation: _line,
                    builder: (context, _) => Positioned(
                      top: _line.value * (widget.scanSize - 2),
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.ember2.withValues(alpha: 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppColors.ember2, width: 3);
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? side : BorderSide.none,
          bottom: isTop ? BorderSide.none : side,
          left: isLeft ? side : BorderSide.none,
          right: isLeft ? BorderSide.none : side,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? const Radius.circular(8) : Radius.zero,
          topRight: isTop && !isLeft ? const Radius.circular(8) : Radius.zero,
          bottomLeft: !isTop && isLeft ? const Radius.circular(8) : Radius.zero,
          bottomRight:
              !isTop && !isLeft ? const Radius.circular(8) : Radius.zero,
        ),
      ),
    );
  }
}

/// Dims everything except the scan window.
class _CutoutPainter extends CustomPainter {
  const _CutoutPainter({required this.scanSize});

  final double scanSize;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hole = Rect.fromCenter(
      center: rect.center,
      width: scanSize,
      height: scanSize,
    );

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.7));
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, const Radius.circular(8)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CutoutPainter oldDelegate) =>
      oldDelegate.scanSize != scanSize;
}
