import 'package:flutter/material.dart';

class LessonStagePot extends StatelessWidget {
  final double progress; // 0.0 to 1.0 (0% to 100%)
  final bool isCrownUnlocked;
  final double size;

  const LessonStagePot({
    Key? key,
    required this.progress,
    this.isCrownUnlocked = false,
    this.size = 54,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isCrownUnlocked || progress >= 1.0) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Icon(
              Icons.stars_rounded,
              size: size * 0.65,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Determine Pot Variant Stage
    Color potColor;
    Color topSoilColor = const Color(0xFF8B5A2B);
    Widget plantDecoration;

    if (progress <= 0.05) {
      // Empty pot / grey state
      potColor = const Color(0xFFCFD8DC);
      plantDecoration = const SizedBox.shrink();
    } else if (progress < 0.4) {
      // Sprout stage 🌱
      potColor = const Color(0xFFF4A261);
      plantDecoration = const Icon(
        Icons.eco,
        size: 22,
        color: Color(0xFF4CAF50),
      );
    } else if (progress < 0.8) {
      // Growing plant stage 🪴
      potColor = const Color(0xFFE76F51);
      plantDecoration = const Icon(
        Icons.local_florist,
        size: 26,
        color: Color(0xFF2E7D32),
      );
    } else {
      // Bloomed flower stage 🌸
      potColor = const Color(0xFFE07A5F);
      plantDecoration = Stack(
        alignment: Alignment.center,
        children: const [
          Icon(Icons.local_florist, size: 28, color: Color(0xFF43A047)),
          Positioned(
            top: 0,
            child: Icon(Icons.filter_vintage, size: 16, color: Color(0xFFFF4081)),
          ),
        ],
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Plant / Sprout on top
          Positioned(
            top: 2,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: plantDecoration,
            ),
          ),

          // Terracotta Pot Base
          Positioned(
            bottom: 2,
            child: Container(
              width: size * 0.58,
              height: size * 0.42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [potColor, potColor.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: potColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Rim on top of pot
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: topSoilColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
