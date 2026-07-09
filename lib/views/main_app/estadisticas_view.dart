import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/views/main_app/widgets/my_alerts_entry_tile.dart';

/// Pestaña Estadísticas: historial personal de alertas y métricas futuras.
class EstadisticasView extends StatelessWidget {
  const EstadisticasView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final w = MediaQuery.sizeOf(context).width;
    final pad = w < 360 ? 16.0 : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: Text(
          l10n.statistics,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 32),
          children: [
            Text(
              l10n.myAlertsStatisticsSectionLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            const MyAlertsEntryTile(),
          ],
        ),
      ),
    );
  }
}
