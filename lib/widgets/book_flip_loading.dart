import 'package:flutter/material.dart';

class BookFlipLoading extends StatefulWidget {
  const BookFlipLoading({super.key});

  @override
  State<BookFlipLoading> createState() => _BookFlipLoadingState();
}

class _BookFlipLoadingState extends State<BookFlipLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159, // Full rotation
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: const Icon(
            Icons.menu_book,
            size: 50,
            color: Color(0xFFFFEB3B),
          ),
        );
      },
    );
  }
}
