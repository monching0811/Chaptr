import 'package:flutter/material.dart';
import 'dart:math' as math;

class LogoLoading extends StatefulWidget {
  const LogoLoading({super.key});

  @override
  State<LogoLoading> createState() => _LogoLoadingState();
}

class _LogoLoadingState extends State<LogoLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pageTurnAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _pageTurnAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pageTurnAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(120, 120),
          painter: BookPageTurnPainter(_pageTurnAnimation.value),
        );
      },
    );
  }
}

class BookPageTurnPainter extends CustomPainter {
  final double progress;

  BookPageTurnPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bookWidth = size.width * 0.7;
    final bookHeight = size.height * 0.8;
    final pageThickness = 2.0;

    // Draw book spine (back cover)
    final spinePaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;
    
    final spineRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: bookWidth,
        height: bookHeight,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(spineRect, spinePaint);

    // Draw book cover (front)
    final coverPaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..style = PaintingStyle.fill;
    
    final coverRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - bookWidth * 0.02, center.dy),
        width: bookWidth * 0.98,
        height: bookHeight,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(coverRect, coverPaint);

    // Draw book cover border
    final borderPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(coverRect, borderPaint);

    // Draw page turning animation - simplified version
    final pageTurnProgress = (progress % 1.0);
    if (pageTurnProgress > 0.05) {
      final turnAngle = pageTurnProgress * math.pi * 0.85; // 85% rotation for smooth loop
      
      // Calculate the turning page position
      final pageWidth = bookWidth * 0.92;
      final hingeX = center.dx - bookWidth / 2 + 3;
      
      // Calculate the turning page's right edge position based on angle
      final pageRightX = hingeX + pageWidth * math.cos(turnAngle);
      
      // Draw the turning page (white)
      final pagePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      // Create path for the turning page
      final path = Path();
      path.moveTo(hingeX, center.dy - bookHeight / 2);
      path.lineTo(pageRightX, center.dy - bookHeight / 2);
      path.lineTo(pageRightX, center.dy + bookHeight / 2);
      path.lineTo(hingeX, center.dy + bookHeight / 2);
      path.close();
      
      canvas.drawPath(path, pagePaint);
      
      // Draw shadow on the turning page for depth
      if (turnAngle < math.pi / 2) {
        final shadowPaint = Paint()
          ..color = Colors.black.withAlpha((0.1 * 255).round())
          ..style = PaintingStyle.fill;
        
        final shadowPath = Path();
        final shadowX = hingeX + (pageRightX - hingeX) * 0.3;
        shadowPath.moveTo(hingeX, center.dy - bookHeight / 2);
        shadowPath.lineTo(shadowX, center.dy - bookHeight / 2);
        shadowPath.lineTo(shadowX, center.dy + bookHeight / 2);
        shadowPath.lineTo(hingeX, center.dy + bookHeight / 2);
        shadowPath.close();
        
        canvas.drawPath(shadowPath, shadowPaint);
      }
      
      // Draw the curved/angled edge of the turning page
      final edgePaint = Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      canvas.drawLine(
        Offset(pageRightX, center.dy - bookHeight / 2),
        Offset(pageRightX, center.dy + bookHeight / 2),
        edgePaint,
      );
    }

    // Draw book lines (simulating text lines)
    final linePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    for (int i = 1; i < 8; i++) {
      final y = center.dy - bookHeight / 3 + (i * bookHeight / 8);
      canvas.drawLine(
        Offset(center.dx - bookWidth / 2 + 5, y),
        Offset(center.dx - 5, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(BookPageTurnPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
