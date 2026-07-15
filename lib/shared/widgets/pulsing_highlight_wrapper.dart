import 'package:flutter/material.dart';

/// Pulsing border while an alert is the active (pending) highlight target.
class PulsingHighlightWrapper extends StatefulWidget {
  const PulsingHighlightWrapper({
    super.key,
    required this.active,
    required this.child,
    this.color = const Color(0xFFFF3B30),
    this.borderRadius = 14,
  });

  final bool active;
  final Widget child;
  final Color color;
  final double borderRadius;

  @override
  State<PulsingHighlightWrapper> createState() => _PulsingHighlightWrapperState();
}

class _PulsingHighlightWrapperState extends State<PulsingHighlightWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulsingHighlightWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = 0.35 + _pulse.value * 0.65;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: widget.color.withValues(alpha: t),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: t * 0.35),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
