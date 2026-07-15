import 'package:flutter/material.dart';

/// Estado vacío compacto para Reportes (Home y Comunidades).
///
/// Una fila: icono + texto breve (+ hint opcional) + acción textual.
/// Colores con contraste ≥ 7:1 sobre blanco (WCAG 2.x AAA texto normal).
class ReportsEmptyInline extends StatelessWidget {
  const ReportsEmptyInline({
    super.key,
    required this.line,
    this.hint,
    required this.actionLabel,
    required this.onAction,
    required this.semanticsLabel,
  });

  final String line;
  final String? hint;
  final String actionLabel;
  final VoidCallback onAction;
  final String semanticsLabel;

  static const _primary = Color(0xFF1C1C1E);
  static const _secondary = Color(0xFF48484A);
  static const _link = Color(0xFF0051A8);
  static const _icon = Color(0xFF636366);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.assignment_outlined,
                size: 18,
                color: _icon,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                      height: 1.2,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: _secondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              label: actionLabel,
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: _link,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  actionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenedor blanco usado en Home (mismo lenguaje que alertas cercanas).
class ReportsEmptyHomeShell extends StatelessWidget {
  const ReportsEmptyHomeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
