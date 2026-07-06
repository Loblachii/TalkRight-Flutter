import 'package:flutter/material.dart';

class OurAdventureScreen extends StatelessWidget {
  const OurAdventureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(255, 252, 244, 1),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/curved_background.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          _TapAnimatedButton(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    offset: const Offset(4, 4),
                    blurRadius: 15,
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.asset(
                'assets/images/backButton.png',
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, size: 24),
                    ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'About Us',
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'Fredoka',
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 54),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Abstract',
                textAlign: TextAlign.justify,
                style: TextStyle(
                  color: Colors.black87,
                  fontFamily: 'Fredoka',
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This study presents the development of "Talk Right: An Android-Based Interactive Learning Tool for Improving Pronunciation Proficiency in Loma Elementary School, Amadeo, Cavite," a mobile learning (M-learning) application designed to support Grade 1 to Grade 3 students in improving their English pronunciation skills. The application serves as a supplementary learning tool that provides structured learning through Interactive Lessons, Exercises, and Assessment Games aligned with the Loma Elementary School syllabus, focusing on sound recognition, word formation, and simple sentence patterns. Overall, the application offers an engaging, accessible, and structured platform that reinforces pronunciation learning beyond the classroom.',
                textAlign: TextAlign.justify,
                style: TextStyle(
                  color: Colors.black87,
                  fontFamily: 'Fredoka',
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'Institution Logo',
          content: '',
          children: [
            // ─── CCT Logo ───
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/cctLogo.png',
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 30),
            // ─── SCS Logo ───
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/scsLogo.png',
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'Beneficiary School Logo',
          content: '',
          children: [
            // ─── Loma Logo ───
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/lomaLogo.png',
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContentCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String content,
    List<Widget>? children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              color: Colors.black,
              fontFamily: 'Fredoka',
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          if (content.isNotEmpty)
            Text(
              content,
              textAlign: TextAlign.justify,
              style: const TextStyle(
                color: Colors.black87,
                fontFamily: 'Fredoka',
                fontSize: 18,
                fontWeight: FontWeight.w300,
                height: 1.3,
              ),
            ),
          if (children != null) ...children,
        ],
      ),
    );
  }
}

// ─── Reusable tap-bounce button wrapper ─────────────────────────────────────
class _TapAnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapAnimatedButton({required this.child, required this.onTap});

  @override
  State<_TapAnimatedButton> createState() => _TapAnimatedButtonState();
}

class _TapAnimatedButtonState extends State<_TapAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.85,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0).then((_) => widget.onTap());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
