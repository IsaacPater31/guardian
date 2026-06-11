import 'package:flutter/material.dart';

class PulsingMapMarker extends StatefulWidget {
  const PulsingMapMarker({
    super.key,
    required this.color,
    required this.icon,
    required this.isHighlighted,
    required this.isAttended,
    required this.hasOffset,
    required this.offsetLevel,
  });

  final Color color;
  final IconData icon;
  final bool isHighlighted;
  final bool isAttended;
  final bool hasOffset;
  final int offsetLevel;

  @override
  State<PulsingMapMarker> createState() => _PulsingMapMarkerState();
}

class _PulsingMapMarkerState extends State<PulsingMapMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.isHighlighted) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulsingMapMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isHighlighted) {
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
    final ringColor = widget.isHighlighted
        ? const Color(0xFFFF3B30)
        : (widget.hasOffset ? Colors.yellow : Colors.white);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final ringWidth = widget.isHighlighted
            ? 3.0 + (_pulse.value * 2.0)
            : (widget.hasOffset ? 3.0 : 2.0);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.isHighlighted
                ? [
                    BoxShadow(
                      color: const Color(
                        0xFFFF3B30,
                      ).withValues(alpha: 0.25 + _pulse.value * 0.45),
                      blurRadius: 10 + _pulse.value * 8,
                      spreadRadius: 1 + _pulse.value * 2,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: ringWidth),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 20),
              ),
              if (widget.isAttended)
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: _AttendedBadge(),
                ),
              if (widget.hasOffset && !widget.isAttended)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.yellow,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.offsetLevel + 1}',
                        style: const TextStyle(
                          fontSize: 6,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AttendedBadge extends StatelessWidget {
  const _AttendedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: Color(0xFF34C759),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 9),
    );
  }
}
