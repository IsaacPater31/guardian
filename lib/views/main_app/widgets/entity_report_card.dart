import 'package:flutter/material.dart';
import 'package:guardian/core/app_constants.dart';
import 'package:guardian/core/community_icon_catalog.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/models/entity_report_type.dart';
import 'package:guardian/views/main_app/widgets/community_icon_picker.dart';

/// Franja de tarjetas de reporte a entidades (estilo Home anterior).
class EntityReportCardsStrip extends StatelessWidget {
  const EntityReportCardsStrip({
    super.key,
    required this.entities,
    required this.onReport,
  });

  final List<Map<String, dynamic>> entities;
  final void Function(Map<String, dynamic> entity) onReport;
  static const String _defaultReportButtonHex = '#0D1B3E';

  static Color _accentFromEntity(Map<String, dynamic> entity) {
    final hex = entity[CommunityFields.reportButtonColor] as String?;
    if (hex != null && hex.isNotEmpty) {
      return CommunityIconPicker.colorFromHex(hex);
    }
    return CommunityIconPicker.colorFromHex(_defaultReportButtonHex);
  }

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final hx = mq.size.width < 360 ? 8.0 : 12.0;
    final gap = 10.0;
    final bottomExtra = mq.padding.bottom > 16
        ? 6.0
        : mq.padding.bottom > 0
            ? 8.0
            : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hx, 6, hx, bottomExtra),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < entities.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              EntityReportCard(
                entity: entities[i],
                accent: _accentFromEntity(entities[i]),
                onReport: () => onReport(entities[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EntityReportCard extends StatelessWidget {
  const EntityReportCard({
    super.key,
    required this.entity,
    required this.accent,
    required this.onReport,
  });

  final Map<String, dynamic> entity;
  final Color accent;
  final VoidCallback onReport;

  static const double _pad = 12;
  static const double _iconBox = 30;
  static const double _btnHPad = 14;
  static const double _btnVPad = 8;
  static const double _btnFontSize = 13;
  static const double _titleFontSize = 13;
  static const double _subtitleFontSize = 11.5;
  static const double _radius = 12;
  static const double _btnRadius = 8;
  /// Holgura para que el glifo real no quede más ancho que TextPainter.
  static const double _measureSlack = 4;
  /// Tope para nombres muy largos (el título hace wrap dentro).
  static const double _maxContentW = 168;

  static Color _onColorFor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.37 ? const Color(0xFF111111) : Colors.white;
  }

  static double _measureTextWidth(
    String text,
    TextStyle style,
    TextScaler scaler, {
    int maxLines = 1,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: maxLines,
    )..layout();
    return painter.width + _measureSlack;
  }

  /// Ancho del botón = texto Enviar + padding.
  static double _measureButtonWidth(
    String label,
    TextStyle style,
    TextScaler scaler,
  ) {
    return _measureTextWidth(label, style, scaler) + (_btnHPad * 2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = (entity[CommunityFields.name] as String?) ?? '';
    final codePoint =
        entity[CommunityFields.iconCodePoint] as int? ??
            CommunityIconCatalog.defaultIconCodePoint;
    final icon = CommunityIconPicker.iconFromCodePoint(codePoint);
    final surfaceTint =
        Color.alphaBlend(accent.withValues(alpha: 0.05), Colors.white);
    const primaryText = Color(0xFF111827);
    const secondaryText = Color(0xFF4B5563);
    final buttonText = _onColorFor(accent);
    final scaler = MediaQuery.textScalerOf(context);

    final btnLabel = l10n.sendReportAction;
    final btnStyle = TextStyle(
      color: buttonText,
      fontSize: _btnFontSize,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );
    const titleStyle = TextStyle(
      color: primaryText,
      fontWeight: FontWeight.w800,
      fontSize: _titleFontSize,
      height: 1.2,
      letterSpacing: -0.1,
    );
    const subtitleStyle = TextStyle(
      color: secondaryText,
      fontWeight: FontWeight.w600,
      fontSize: _subtitleFontSize,
      height: 1.1,
    );

    final title = l10n.reportEntityTile(name);
    final subtitle = l10n.entityReportLabel;
    final buttonW = _measureButtonWidth(btnLabel, btnStyle, scaler);
    final titleW = _measureTextWidth(title, titleStyle, scaler);
    final subtitleW = _measureTextWidth(subtitle, subtitleStyle, scaler);
    // Se acopla al título variable "Reporte {nombre}" y al botón Enviar.
    final contentW =
        [buttonW, titleW, subtitleW].reduce((a, b) => a > b ? a : b)
            .clamp(buttonW, _maxContentW);

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        onTap: onReport,
        borderRadius: BorderRadius.circular(_radius),
        splashColor: accent.withValues(alpha: 0.15),
        highlightColor: accent.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            color: surfaceTint,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(_pad),
            child: SizedBox(
              width: contentW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: _iconBox,
                    width: _iconBox,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(icon, color: accent, size: _iconBox * 0.55),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: accent,
                    borderRadius: BorderRadius.circular(_btnRadius),
                    child: InkWell(
                      onTap: onReport,
                      borderRadius: BorderRadius.circular(_btnRadius),
                      child: SizedBox(
                        width: buttonW,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: _btnVPad,
                          ),
                          child: Text(
                            btnLabel,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: btnStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Parsea los tipos de reporte personalizados de una entidad.
List<EntityReportType> parseEntityReportAlertTypes(Map<String, dynamic> entity) {
  return EntityReportType.parseList(entity[CommunityFields.reportAlertTypes]);
}
