import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';

class OurTeamScreen extends StatefulWidget {
  const OurTeamScreen({super.key});

  @override
  State<OurTeamScreen> createState() => _OurTeamScreenState();
}

class _OurTeamScreenState extends State<OurTeamScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  static const int _infiniteScrollOffset = 10000;

  final List<Map<String, String>> teamMembers = [
    {
      'name': 'John Sean T. Bataclan',
      'role': 'Main Developer',
      'email': 'johnseanbtcln05@gmail.com',
      'course': 'BSIT 4-1',
      'image': 'assets/images/johnSean.png',
      'qrLink': 'https://www.facebook.com/JSeanbataclan',
    },
    {
      'name': 'Aljo A. Labores',
      'role': 'Q.A. Developer',
      'email': 'aljoalabares@gmail.com',
      'course': 'BSIT 4-1',
      'image': 'assets/images/alJo.png', // anonymous — renders fallback avatar
      'qrLink': 'https://www.facebook.com/Heneral.ll',
    },
    {
      'name': 'Frankleen C. Legaspi',
      'role': 'Lead Documentation',
      'email': 'frankleenlegaspi@gmail.com',
      'course': 'BSIT 4-1',
      'image': 'assets/images/frankleenMae.png',
      'qrLink': 'https://www.facebook.com/franxleenmae',
    },
    {
      'name': 'Jhonpaul Z. Jamiladan',
      'role': 'Q.A. Document',
      'email': 'jhonpauljamiladan@gmail.com',
      'course': 'BSIT 4-1',
      'image': 'assets/images/jhonPaul.png',
      'qrLink': 'https://www.facebook.com/jhonpaul.jamiladan',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: _infiniteScrollOffset,
    );
    _pageController.addListener(() {
      int next = _pageController.page!.round() % teamMembers.length;
      if (_currentPage != next) {
        setState(() => _currentPage = next);
      }
    });
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 5000), (_) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _pageController.page!.round() + 1,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _resetAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ─── Build ───

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
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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

  // ─── Header ───

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          // ─── Back button with tap animation ───
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
                'Our Team',
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

  // ─── Body ───

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Meet the Team!',
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
                'It started with a shared observation—the universal struggle of mastering English pronunciation. From this challenge, a solution grew. We are the researchers and developers from City College of Tagaytay who believed learning to speak clearly should be fun, not frustrating. We created Talk Right to be the interactive, supportive companion that turns practice into play and struggles into successes.',
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

        _buildTeamCarousel(),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'Acknowledgements and Credits',
          content:
              'This application was developed to support the English pronunciation learning process for students of Loma Elementary School, Amadeo, Cavite. It follows a universal approach to language learning, designed to guide and help students improve their pronunciation skills and speaking confidence. The lesson content of the application is aligned with the Loma Elementary School syllabus, ensuring that the instructional materials are relevant, structured, and appropriate for the learners’ grade level. In addition, the application incorporates materials from reputable online resources to ensure the accuracy, accessibility, and quality of the learning content.',
          children: [
            const SizedBox(height: 16),
            _buildSubsection('Educational Content', '• Scribd \n• EnglishClub'),
            const SizedBox(height: 16),
            _buildSubsection(
              'Graphics and Visual Assets',
              '• Canva \n• Feather \n• Pinterest \n• Figma',
            ),
            const SizedBox(height: 16),
            const Text(
              'We acknowledge and respect the intellectual property rights of all original creators. While the content has been adapted and integrated to enrich the learning experience, we do not claim ownership of any third-party materials included in this application.',
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
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'Links',
          content: '',
          children: [
            _buildSubsection(
              'Educational Content',
              "• Scribd: https://www.scribd.com \n• EnglishClub: https://www.englishclub.com \n• ReadNaturally: https://readnaturally.com \n• Rock 'N Learn: https://www.youtube.com/@rocknlearn",
            ),
            const SizedBox(height: 16),
            _buildSubsection(
              'Graphics and Visual Assets',
              '• Canva: https://www.canva.com \n• Feather: https://feathericons.com \n• Pinterest: https://ph.pinterest.com \n• Figma: https://www.figma.com',
            ),
          ],
        ),
      ],
    );
  }

  // ─── Team Carousel ───

  Widget _buildTeamCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 400,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _resetAutoScrollTimer();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemBuilder: (context, index) {
                final memberIndex = index % teamMembers.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: _TeamMemberCard(member: teamMembers[memberIndex]),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            teamMembers.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _currentPage == index ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color:
                    _currentPage == index
                        ? const Color.fromARGB(255, 110, 67, 3)
                        : const Color.fromARGB(255, 136, 135, 135),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Card Widgets ───

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
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildSubsection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontFamily: 'Fredoka',
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: Colors.black87,
            fontFamily: 'Fredoka',
            fontSize: 18,
            fontWeight: FontWeight.w300,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ─── Team Member Card (flip card) ───

class _TeamMemberCard extends StatefulWidget {
  final Map<String, String> member;
  const _TeamMemberCard({required this.member});

  @override
  State<_TeamMemberCard> createState() => _TeamMemberCardState();
}

class _TeamMemberCardState extends State<_TeamMemberCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * math.pi;
          final transform =
              Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child:
                angle <= math.pi / 2
                    ? _buildFrontCard()
                    : Transform(
                      transform: Matrix4.identity()..rotateY(math.pi),
                      alignment: Alignment.center,
                      child: _buildBackCard(),
                    ),
          );
        },
      ),
    );
  }

  Widget _buildFrontCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE0E0E0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child:
                  widget.member['image']!.isNotEmpty
                      ? Image.asset(
                        widget.member['image']!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.person,
                              size: 80,
                              color: Color(0xFF9E9E9E),
                            ),
                      )
                      : const Icon(
                        Icons.person,
                        size: 80,
                        color: Color(0xFF9E9E9E),
                      ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.member['name']!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontFamily: 'Fredoka',
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.member['role']!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Tap to see details',
              style: TextStyle(
                color: Color(0xFFFF9800),
                fontFamily: 'Fredoka',
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard() {
    final String qrLink = widget.member['qrLink'] ?? 'https://example.com';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFFF9800).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ─── Real QR code generated from the member's unique link ───
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: QrImageView(
              data: qrLink,
              version: QrVersions.auto,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.member['course']!,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Fredoka',
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.member['email']!,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Fredoka',
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap to flip back',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontFamily: 'Fredoka',
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable tap-bounce button wrapper ─────────────────────────────────────
/// Wraps any widget with a bounce animation on tap.
/// Shrinks → overshoots → settles back to normal scale.
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
    // Shrink → overshoot → settle
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
