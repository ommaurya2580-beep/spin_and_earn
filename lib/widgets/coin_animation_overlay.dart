import 'package:flutter/material.dart';
import 'dart:math' as math;

class CoinAnimationOverlay {
  static void show(BuildContext context, int amount) {
    if (amount <= 0) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _FloatingCoinWidget(
        amount: amount,
        onAnimationComplete: () {
          overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _FloatingCoinWidget extends StatefulWidget {
  final int amount;
  final VoidCallback onAnimationComplete;

  const _FloatingCoinWidget({
    required this.amount,
    required this.onAnimationComplete,
  });

  @override
  State<_FloatingCoinWidget> createState() => _FloatingCoinWidgetState();
}

class _FloatingCoinWidgetState extends State<_FloatingCoinWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -2.5), // Move upwards
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOutQuad),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      widget.onAnimationComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height / 2 - 100, // Move up slightly to allow confetti spread
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Confetti Layer
            _ConfettiExplosion(controller: _controller),
            
            // Coin Layer
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🪙', // Coin Emoji
                        style: TextStyle(fontSize: 50),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '+${widget.amount} Coins',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                            ),
                            // Stroke effect
                            const Shadow(
                              offset: Offset(-1, -1),
                              color: Colors.black,
                            ),
                            const Shadow(
                              offset: Offset(1, -1),
                              color: Colors.black,
                            ),
                            const Shadow(
                              offset: Offset(1, 1),
                              color: Colors.black,
                            ),
                            const Shadow(
                              offset: Offset(-1, 1),
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiExplosion extends StatelessWidget {
  final AnimationController controller;
  
  const _ConfettiExplosion({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
         return CustomPaint(
           painter: _ConfettiPainter(progress: controller.value),
           size: const Size(300, 300),
         );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<Color> colors = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.yellow];
  
  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress > 0.6) return; // Disappear early
    
    final Paint paint = Paint();
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    
    // Simulate 30 particles based on progress
    // We use a deterministic pseudo-random logic based on index to keep particles stable during animation
    for (int i = 0; i < 30; i++) {
        final double angle = (i * (360 / 30)) * (3.14159 / 180); // Radians
        final double speed = 1.0 + (i % 3) * 0.5;
        
        // Expansion
        double currentRadius = (progress * maxRadius * speed * 2.5); // Fast expansion
        if (currentRadius > maxRadius) currentRadius = maxRadius;
        
        final double x = center.dx + currentRadius * math.cos(angle);
        final double y = center.dy + currentRadius * math.sin(angle);
        
        // Opacity fade out
        double opacity = 1.0 - (progress / 0.5); 
        if (opacity < 0) opacity = 0;
        
        paint.color = colors[i % colors.length].withOpacity(opacity);
        paint.style = PaintingStyle.fill;
        
        canvas.drawCircle(Offset(x,y), 4 + (i % 3).toDouble(), paint); // Different sizes
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

