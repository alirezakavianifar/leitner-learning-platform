import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';

class TourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;

  TourStep({
    required this.targetKey,
    required this.title,
    required this.description,
  });
}

class InteractiveTourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const InteractiveTourOverlay({
    Key? key,
    required this.steps,
    required this.onComplete,
    required this.onSkip,
  }) : super(key: key);

  @override
  State<InteractiveTourOverlay> createState() => _InteractiveTourOverlayState();
}

class _InteractiveTourOverlayState extends State<InteractiveTourOverlay> with SingleTickerProviderStateMixin {
  int _currentStepIdx = 0;

  @override
  void initState() {
    super.initState();
    // Rebuild after first frame to ensure GlobalKeys are laid out and context is active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Rect? _getTargetRect() {
    if (_currentStepIdx >= widget.steps.length) return null;
    final key = widget.steps[_currentStepIdx].targetKey;
    final context = key.currentContext;
    if (context == null) return null;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }

  void _nextStep() {
    if (_currentStepIdx < widget.steps.length - 1) {
      setState(() {
        _currentStepIdx++;
      });
    } else {
      widget.onComplete();
    }
  }

  void _prevStep() {
    if (_currentStepIdx > 0) {
      setState(() {
        _currentStepIdx--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final targetRect = _getTargetRect();
    final currentStep = widget.steps[_currentStepIdx];

    final double tooltipWidth = 300;
    final double left = ((size.width - tooltipWidth) / 2).clamp(16.0, size.width - tooltipWidth - 16.0);

    double? top;
    double? bottom;

    if (targetRect == null) {
      top = (size.height - 200) / 2;
    } else {
      if (targetRect.center.dy < size.height / 2) {
        top = targetRect.bottom + 16;
      } else {
        bottom = (size.height - targetRect.top) + 16;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dark background with transparent cutout
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.72),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        backgroundBlendMode: BlendMode.dstOut,
                      ),
                    ),
                  ),
                  if (targetRect != null)
                    Positioned.fromRect(
                      rect: targetRect.inflate(6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Glowing border indicator around the highlighted area
          if (targetRect != null)
            Positioned.fromRect(
              rect: targetRect.inflate(6),
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Animated Tooltip Card
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            left: left,
            width: tooltipWidth,
            top: top,
            bottom: bottom,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step Title & Skip button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            currentStep.title,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: widget.onSkip,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Description text
                    Text(
                      currentStep.description,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Navigation buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Back button (disabled on step 0)
                        TextButton(
                          onPressed: _currentStepIdx > 0 ? _prevStep : null,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: const Text('Back'),
                        ),

                        // Center: Page Indicators
                        Row(
                          children: List.generate(
                            widget.steps.length,
                            (index) => Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentStepIdx == index
                                    ? AppColors.primary
                                    : AppColors.textSecondary.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),

                        // Right: Next/Done button
                        ElevatedButton(
                          onPressed: _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text(
                            _currentStepIdx == widget.steps.length - 1 ? 'Done' : 'Next',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
