import 'package:flutter/material.dart';

class LogoLoading extends StatefulWidget {
  const LogoLoading({super.key});

  @override
  State<LogoLoading> createState() => _LogoLoadingState();
}

class _LogoLoadingState extends State<LogoLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 3.14159, // 180 degrees for flip
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
      animation: _flipAnimation,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.rotationY(_flipAnimation.value),
          alignment: Alignment.center,
          child: Image.asset('logo/chaptrLOGO.jpg', width: 100, height: 100),
        );
      },
    );
  }
}
