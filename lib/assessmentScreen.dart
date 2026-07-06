import 'dart:math';
import 'package:capstone_project/assessmentTab.dart';
import 'package:flutter/material.dart';
import 'progress_manager.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  double _stage1Progress = 0.0;
  double _stage2Progress = 0.0;
  double _stage3Progress = 0.0;

  bool _isStageUnlocked(String stageId) {
    final pm = ProgressManager();
    switch (stageId) {
      case 'stage1':
        for (int i = 0; i < 6; i++) {
          if (!pm.isLessonFullyCompleted('course_one', i)) return false;
        }
        return true;
      case 'stage2':
        for (int i = 0; i < 6; i++) {
          if (!pm.isLessonFullyCompleted('course_two', i)) return false;
        }
        return true;
      case 'stage3':
        for (int i = 0; i < 6; i++) {
          if (!pm.isLessonFullyCompleted('course_three', i)) return false;
        }
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  void _loadProgress() {
    final pm = ProgressManager();
    setState(() {
      _stage1Progress = pm.getAssessmentStagePercentage('stage1');
      _stage2Progress = pm.getAssessmentStagePercentage('stage2');
      _stage3Progress = pm.getAssessmentStagePercentage('stage3');
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final circleSize = screenWidth * 0.22;
    final strokeWidth = circleSize * 0.1;
    final stage1Unlocked = _isStageUnlocked('stage1');
    final stage2Unlocked = _isStageUnlocked('stage2');
    final stage3Unlocked = _isStageUnlocked('stage3');

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/assessmentBackground.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Title Image at the top
                Padding(
                  padding: EdgeInsets.only(top: screenHeight * 0.06),
                  child: Center(
                    child: Image.asset(
                      'assets/images/talkRightAssessment.png',
                      width: screenWidth * 0.75,
                      height: screenHeight * 0.12,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                SizedBox(height: screenHeight * 0.04),

                const Spacer(),

                // Circular Progress Indicators
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCircularProgress(
                        'Stage 1',
                        _stage1Progress,
                        const Color(0xFF4CAF50),
                        circleSize,
                        strokeWidth,
                        isLocked: !stage1Unlocked,
                      ),
                      _buildCircularProgress(
                        'Stage 2',
                        _stage2Progress,
                        const Color(0xFF4A90D9),
                        circleSize,
                        strokeWidth,
                        isLocked: !stage2Unlocked,
                      ),
                      _buildCircularProgress(
                        'Stage 3',
                        _stage3Progress,
                        const Color(0xFF9C27B0),
                        circleSize,
                        strokeWidth,
                        isLocked: !stage3Unlocked,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * 0.03),

                // Start Button at the bottom
                Padding(
                  padding: EdgeInsets.only(bottom: screenHeight * 0.08),
                  child: Center(
                    child: Container(
                      clipBehavior: Clip.hardEdge,
                      height: screenHeight * 0.065,
                      width: screenWidth * 0.72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          // Navigate to AssessmentTab with slide animation
                          await Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const AssessmentTab(),
                              transitionsBuilder: (
                                context,
                                animation,
                                secondaryAnimation,
                                child,
                              ) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
                                const curve = Curves.easeInOut;

                                var tween = Tween(
                                  begin: begin,
                                  end: end,
                                ).chain(CurveTween(curve: curve));
                                var offsetAnimation = animation.drive(tween);

                                return SlideTransition(
                                  position: offsetAnimation,
                                  child: child,
                                );
                              },
                              transitionDuration: const Duration(
                                milliseconds: 400,
                              ),
                            ),
                          );
                          // Refresh progress when returning from AssessmentTab
                          _loadProgress();
                        },
                        child: Image.asset(
                          'assets/images/startAssessmentButton.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(
    String label,
    double progress,
    Color color,
    double size,
    double strokeWidth, {
    bool isLocked = false,
  }) {
    final percent = (progress * 100).round();
    final fontSize = size * 0.22;
    final labelFontSize = size * 0.16;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _CircularProgressPainter(
              progress: isLocked ? 0 : progress,
              color: color,
              strokeWidth: strokeWidth,
              backgroundColor: Colors.white.withOpacity(0.4),
            ),
            child: Center(
              child:
                  isLocked
                      ? Icon(Icons.lock, color: Colors.white, size: size * 0.34)
                      : Text(
                        '$percent%',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
            ),
          ),
        ),
        SizedBox(height: size * 0.1),
        Text(
          isLocked ? '$label Locked' : label,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: labelFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
