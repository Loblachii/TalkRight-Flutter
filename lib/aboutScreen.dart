import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'ourAdventureScreen.dart';
import 'ourTeamScreen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _driveLink =
      'https://drive.google.com/drive/folders/1GDj2XeAvfHTyRsNhI8U6DDPAlVaf5sgd?usp=drive_link';

  // ─── Show QR Modal ───

  void _showQRModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => const _QRShareDialog(driveLink: _driveLink),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/about_background.png',
            fit: BoxFit.cover,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: _buildBody(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Header ───

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: const Text(
        'About',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Fredoka',
          fontSize: 26,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ─── Body ───

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildInfoCard(
          context: context,
          title: 'About Us',
          subtitle: 'The story behind the magic.',
          buttonText: 'View',
          onPressed: () {
            Navigator.of(context).push(_createRouteToOurAdventure());
          },
        ),
        const SizedBox(height: 20),
        _buildInfoCard(
          context: context,
          title: 'Our Team',
          subtitle: 'Your learning adventure squad!',
          buttonText: 'View',
          onPressed: () {
            Navigator.of(context).push(_createRouteToOurTeam());
          },
        ),
        const SizedBox(height: 20),
        _buildInfoCard(
          context: context,
          title: 'Share the magic of reading!',
          subtitle: "Let's learn together!",
          buttonText: 'Share',
          onPressed: () => _showQRModal(context),
        ),
      ],
    );
  }

  // ─── Info Card ───

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
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
            style: const TextStyle(
              color: Colors.black,
              fontFamily: 'Fredoka',
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black87,
              fontFamily: 'Fredoka',
              fontSize: 18,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            // ─── View / Share button with tap animation ───
            child: _TapAnimatedButton(
              onTap: onPressed,
              child: Container(
                width: 110,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFB8500),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      offset: const Offset(-1, -1),
                      blurRadius: 6,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      offset: const Offset(1, 1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w400,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Route Transitions ───

  Route _createRouteToOurAdventure() {
    return PageRouteBuilder(
      pageBuilder:
          (context, animation, secondaryAnimation) =>
              const OurAdventureScreen(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  Route _createRouteToOurTeam() {
    return PageRouteBuilder(
      pageBuilder:
          (context, animation, secondaryAnimation) => const OurTeamScreen(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }
}

// ─── QR Share Dialog ───

class _QRShareDialog extends StatefulWidget {
  final String driveLink;

  const _QRShareDialog({required this.driveLink});

  @override
  State<_QRShareDialog> createState() => _QRShareDialogState();
}

class _QRShareDialogState extends State<_QRShareDialog> {
  bool _copied = false;

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.driveLink));
    setState(() => _copied = true);

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title ──
            const Text(
              'Share the Magic! ✨',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Scan the QR code to open the link',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 15,
                fontWeight: FontWeight.w300,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),

            // ── QR Code ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFB8500).withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: QrImageView(
                data: widget.driveLink,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // ─── Copy Link button with tap animation ───
            _TapAnimatedButton(
              onTap: _copyLink,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      _copied
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFB8500),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _copied ? Icons.check : Icons.copy_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _copied ? 'Copied!' : 'Copy Link',
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    // Play bounce, then fire the callback once animation completes
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
