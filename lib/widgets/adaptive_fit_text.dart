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

    if (maxLines <= 1) {
      return SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: _alignment(textAlign),
          child: Text(
            text,
            textAlign: textAlign,
            maxLines: 1,
            softWrap: false,
            style: style,
          ),
        ),
      );
    }

    final lines = text
        .replaceAll('\r', '')
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const SizedBox.shrink();

    final lineStyle = style.copyWith(height: 1.05);
    final gap = (style.fontSize ?? 14) * 0.08;

    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: _alignment(textAlign),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                Text(
                  lines[i],
                  textAlign: textAlign,
                  maxLines: 1,
                  softWrap: false,
                  style: lineStyle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
