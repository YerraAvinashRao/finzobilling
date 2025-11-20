import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedAccountantAssistant extends StatefulWidget {
  final int completedFields;
  final String? currentMessage;
  final bool showCelebration;

  const AnimatedAccountantAssistant({
    super.key,
    required this.completedFields,
    this.currentMessage,
    this.showCelebration = false,
  });

  @override
  State<AnimatedAccountantAssistant> createState() =>
      _AnimatedAccountantAssistantState();
}

class _AnimatedAccountantAssistantState
    extends State<AnimatedAccountantAssistant>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Color _getProgressColor() {
    if (widget.completedFields >= 5) return const Color(0xFF34C759);
    if (widget.completedFields >= 3) return const Color(0xFF007AFF);
    return const Color(0xFF8E8E93);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entranceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(40 * (1 - _entranceAnimation.value), 0),
          child: Opacity(
            opacity: _entranceAnimation.value,
            child: child,
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Speech bubble
          if (widget.currentMessage != null)
            Positioned(
              bottom: 105,
              right: -5,
              child: _buildSpeechBubble(),
            ),

          // Avatar - YOUR IMAGE!
          Container(
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: _getProgressColor().withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/accountant_avatar.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback icon if image fails
                  return Container(
                    color: Colors.grey.shade100,
                    child: Icon(
                      Icons.account_circle,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                  );
                },
              ),
            ),
          ),

          // Progress ring
          if (widget.completedFields > 0)
            SizedBox(
              width: 85,
              height: 85,
              child: CustomPaint(
                painter: ProgressRingPainter(
                  progress: widget.completedFields / 5,
                  color: _getProgressColor(),
                ),
              ),
            ),

          // Success badge
          if (widget.showCelebration)
            Positioned(
              top: 0,
              right: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeechBubble() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              constraints: const BoxConstraints(maxWidth: 130),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.currentMessage!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Progress ring
class ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  ProgressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = color;

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 2,
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(ProgressRingPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
