import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

class SlideToConfirmQuick extends StatefulWidget {
  const SlideToConfirmQuick({
    super.key,
    required this.onConfirmed,
    required this.isBusy,
  });

  final Future<void> Function() onConfirmed;
  final bool isBusy;

  @override
  State<SlideToConfirmQuick> createState() => _SlideToConfirmQuickState();
}

class _SlideToConfirmQuickState extends State<SlideToConfirmQuick> {
  static const double _triggerAt = 0.9;
  double _progress = 0;
  bool _sending = false;

  double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

  double _lerpDouble(double a, double b, double t) => a + (b - a) * _clamp01(t);

  double _fluidScale(
    double input, {
    required double inMin,
    required double inMax,
  }) {
    if (inMax <= inMin) return 0;
    return _clamp01((input - inMin) / (inMax - inMin));
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _progress = 0;
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth;
        final t = _fluidScale(cardW, inMin: 280, inMax: 960);
        final compact = cardW < 380;
        final contentHeight = _lerpDouble(96.0, 122.0, t).clamp(96.0, 122.0);
        final knobSize = _lerpDouble(
          compact ? 74.0 : 84.0,
          102.0,
          t,
        ).clamp(compact ? 74.0 : 84.0, 102.0);
        final centerLeft = (cardW - knobSize) / 2;
        final rightLeft = math.max(centerLeft, cardW - knobSize - 10);
        final travel = rightLeft - centerLeft;
        final knobLeft = centerLeft + (travel * _progress);
        final slideHintSize = _lerpDouble(10.5, 12.0, t).clamp(10.5, 12.0);
        final titleSize = _lerpDouble(24.0, 33.0, t).clamp(24.0, 33.0);
        final arrowsSize = _lerpDouble(26.0, 36.0, t).clamp(26.0, 36.0);
        final sosSize = _lerpDouble(28.0, 40.0, t).clamp(28.0, 40.0);

        return GestureDetector(
          onHorizontalDragUpdate: (_sending || widget.isBusy)
              ? null
              : (details) {
                  final delta = details.delta.dx / (travel <= 0 ? 1 : travel);
                  final next = (_progress + delta).clamp(0.0, 1.0);
                  setState(() => _progress = next);
                },
          onHorizontalDragEnd: (_) async {
            if (_sending || widget.isBusy) return;
            final shouldSend = _progress >= _triggerAt;
            setState(() => _progress = 0);
            if (!shouldSend) return;
            setState(() => _sending = true);
            await widget.onConfirmed();
            _reset();
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              _lerpDouble(12.0, 14.0, t).clamp(12.0, 14.0),
              _lerpDouble(14.0, 16.0, t).clamp(14.0, 16.0),
              _lerpDouble(12.0, 14.0, t).clamp(12.0, 14.0),
              _lerpDouble(14.0, 16.0, t).clamp(14.0, 16.0),
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF2E2E), Color(0xFFE00000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF2E2E).withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SizedBox(
              height: contentHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: compact ? 18 : 22,
                        right: compact ? 18 : 22,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.slideToRequestHelpHint,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontSize: slideHintSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  l10n.slideToRequestHelpAction,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: titleSize,
                                    height: 0.92,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '>>>',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.52),
                                fontSize: arrowsSize,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: knobLeft,
                    top: contentHeight / 2 - knobSize / 2,
                    child: Container(
                      width: knobSize,
                      height: knobSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.45),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: (_sending || widget.isBusy)
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : Text(
                              'SOS',
                              style: TextStyle(
                                color: const Color(0xFFFF2E2E),
                                fontSize: sosSize,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
