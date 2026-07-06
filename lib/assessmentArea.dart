import 'package:flutter/material.dart';

class AssessmentArea extends StatefulWidget {
  final VoidCallback? onStart;
  final VoidCallback? onCancel;

  const AssessmentArea({super.key, this.onStart, this.onCancel});

  @override
  State<AssessmentArea> createState() => _AssessmentAreaState();
}

class _AssessmentAreaState extends State<AssessmentArea> {
  // Store star ratings for each level (1-18)
  final Map<int, int> _levelStars = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 223, 221, 221),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.06,
            vertical: MediaQuery.of(context).size.height * 0.08,
          ),
          child: Column(
            children: [
              _buildLevelWithPath(
                context,
                18,
                const Color(0xFFE8B6B7),
                true,
                true,
              ),
              _buildLevelWithPath(
                context,
                17,
                const Color(0xFFE8B6B7),
                false,
                false,
              ),
              _buildLevelWithPath(
                context,
                16,
                const Color(0xFFE8B6B7),
                true,
                true,
              ),
              _buildLevelWithPath(
                context,
                15,
                const Color(0xFFE8B6B7),
                false,
                false,
              ),
              _buildLevelWithPath(
                context,
                14,
                const Color(0xFFE8B6B7),
                true,
                true,
              ),
              _buildLevelWithPath(
                context,
                13,
                const Color(0xFFE8B6B7),
                false,
                false,
              ),
              _buildLevelWithPath(
                context,
                12,
                const Color(0xFFB6DAE8),
                true,
                true,
              ),
              _buildLevelWithPath(
                context,
                11,
                const Color(0xFFB6DAE8),
                false,
                false,
              ),
              _buildLevelWithPath(
                context,
                10,
                const Color(0xFFB6DAE8),
                true,
                true,
              ),
              _buildLevelWithPath(
                context,
                9,
                const Color(0xFFB6DAE8),
                false,
                false,
              ),
              _buildLevelWithPath(
                context,
                8,
                const Color(0xFFB6DAE8),
                true,
                true,
              ),
              _buildLevelWithPath(
                context,
                7,
                const Color(0xFFB6DAE8),
                false,
                false,
              ),
              _buildLevelWithPath(
                context,
                6,
                const Color(0xFFB6E8C1),
                true,
                true,
              ),
              _buildLevelWithPath(
                context,
                5,
                const Color(0xFFB6E8C1),
                false,
                false,
              ),
              _buildLevelWithPath(
                context,
                4,
                const Color(0xFFB6E8C1),
                true,
                true,
              ),
              _buildLevelWithPath(
                context,
                3,
                const Color(0xFFB6E8C1),
                false,
                false,
              ),
              _buildLevelWithPath(
                context,
                2,
                const Color(0xFFB6E8C1),
                true,
                true,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildLevelButton(
                    context,
                    1,
                    const Color(0xFFB6E8C1),
                    false,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _getStarImage(int level) {
    int stars = _levelStars[level] ?? 0;
    switch (stars) {
      case 3:
        return 'assets/images/threeStar.png';
      case 2:
        return 'assets/images/twoStar.png';
      case 1:
        return 'assets/images/oneStar.png';
      default:
        return 'assets/images/zeroStar.png';
    }
  }

  Widget _buildLevelWithPath(
    BuildContext context,
    int level,
    Color color,
    bool alignLeft,
    bool curvingRight,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonSize = (screenWidth * 0.17).clamp(50.0, 85.0).toDouble();
    final pathHeight = buttonSize * 2.2;
    return SizedBox(
      height: pathHeight,
      child: Stack(
        children: [
          // Draw the path first (behind)
          Positioned.fill(
            child: CustomPaint(
              painter: DottedPathPainter(
                curvingRight: curvingRight,
                buttonRadius: buttonSize / 2,
              ),
            ),
          ),
          // Position button in the middle of the path
          Positioned(
            top: pathHeight * 0.25,
            left: alignLeft ? 0 : null,
            right: alignLeft ? null : 0,
            child: _buildLevelButton(context, level, color, alignLeft),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelButton(
    BuildContext context,
    int level,
    Color color,
    bool alignLeft,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonSize = (screenWidth * 0.17).clamp(50.0, 85.0).toDouble();
    final starWidth = buttonSize * 1.15;
    final starHeight = buttonSize * 0.57;
    final fontSize = buttonSize * 0.34;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Star indicator above button
        Image.asset(
          _getStarImage(level),
          width: starWidth,
          height: starHeight,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if image not found - display star icons
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (index) => Icon(
                  Icons.star_border,
                  size: buttonSize * 0.28,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),
        // Circular button
        GestureDetector(
          onTap: () {
            // Placeholder - to be implemented
          },
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: buttonSize * 0.057,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$level',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DottedPathPainter extends CustomPainter {
  final bool curvingRight;
  final double buttonRadius;

  DottedPathPainter({required this.curvingRight, this.buttonRadius = 35});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.black87
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    final path = Path();
    final midY = size.height / 2;

    if (curvingRight) {
      // Path curves from left to right
      path.moveTo(buttonRadius, 0);
      path.cubicTo(
        buttonRadius,
        midY,
        size.width - buttonRadius,
        midY,
        size.width - buttonRadius,
        size.height,
      );
    } else {
      // Path curves from right to left
      path.moveTo(size.width - buttonRadius, 0);
      path.cubicTo(
        size.width - buttonRadius,
        midY,
        buttonRadius,
        midY,
        buttonRadius,
        size.height,
      );
    }

    // Draw dotted line
    _drawDottedPath(canvas, path, paint);
  }

  void _drawDottedPath(Canvas canvas, Path path, Paint paint) {
    const double dashWidth = 8;
    const double dashSpace = 6;

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final start = metric.getTangentForOffset(distance)?.position;
        distance += dashWidth;
        final end = metric.getTangentForOffset(distance)?.position;

        if (start != null && end != null) {
          canvas.drawLine(start, end, paint);
        }
        distance += dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
