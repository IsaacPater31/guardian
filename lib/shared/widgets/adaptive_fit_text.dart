import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Texto que escala hacia abajo para caber en el espacio disponible.
/// Sin ellipsis: prioriza legibilidad completa en cualquier ancho.
class AdaptiveFitText extends StatelessWidget {
  const AdaptiveFitText({
    super.key,
    required this.text,
    required this.maxWidth,
    this.maxHeight,
    required this.style,
    this.maxLines = 1,
    this.textAlign = TextAlign.center,
    this.minFontSize,
  });

  final String text;
  final double maxWidth;
  final double? maxHeight;
  final TextStyle style;
  final int maxLines;
  final TextAlign textAlign;
  final double? minFontSize;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final baseSize = style.fontSize ?? 14.0;
    final minSize = minFontSize != null
        ? math.min(minFontSize!, baseSize)
        : math.max(8.0, baseSize * 0.75);
    final resolvedMaxHeight = maxHeight ?? double.infinity;

    final fittedFontSize = _resolveFontSize(
      context: context,
      baseSize: baseSize,
      minSize: minSize,
      maxHeight: resolvedMaxHeight,
    );

    final fittedStyle = style.copyWith(
      fontSize: fittedFontSize,
      height: style.height ?? (maxLines > 1 ? 1.05 : 1.0),
    );

    final content = Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      softWrap: maxLines > 1,
      overflow: TextOverflow.visible,
      style: fittedStyle,
    );

    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: Align(
        alignment: _alignment(textAlign),
        child: content,
      ),
    );
  }

  double _resolveFontSize({
    required BuildContext context,
    required double baseSize,
    required double minSize,
    required double maxHeight,
  }) {
    var current = baseSize;
    while (current >= minSize) {
      if (_fits(
        context: context,
        fontSize: current,
        maxHeight: maxHeight,
      )) {
        return current;
      }
      current -= 0.5;
    }
    return minSize;
  }

  bool _fits({
    required BuildContext context,
    required double fontSize,
    required double maxHeight,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          fontSize: fontSize,
          height: style.height ?? (maxLines > 1 ? 1.05 : 1.0),
        ),
      ),
      textAlign: textAlign,
      textDirection: Directionality.of(context),
      maxLines: maxLines,
    );

    painter.layout(minWidth: 0, maxWidth: maxWidth);
    if (painter.didExceedMaxLines) return false;
    if (maxHeight.isFinite && painter.height > maxHeight) return false;
    return true;
  }

  static Alignment _alignment(TextAlign align) {
    switch (align) {
      case TextAlign.left:
      case TextAlign.start:
        return Alignment.centerLeft;
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      default:
        return Alignment.center;
    }
  }
}
