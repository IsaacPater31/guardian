import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/features/communities/domain/community_model.dart';
import 'package:guardian/features/communities/application/community_service.dart';
import 'package:guardian/features/home_shell/presentation/shared/main_tab_navigation.dart';
import 'package:guardian/features/entity_reports/presentation/widgets/entity_report_card.dart';
import 'package:guardian/features/entity_reports/presentation/widgets/report_send_sheet.dart';
import 'package:guardian/features/entity_reports/presentation/widgets/reports_empty_inline.dart';

/// Apartado **Reportes** en Home: tarjetas por entidad (estilo anterior) con
/// color e icono configurados en el panel web.
class HomeReportsSection extends StatefulWidget {
  const HomeReportsSection({
    super.key,
    required this.titleSize,
    required this.topGap,
    required this.rowGap,
  });

  final double titleSize;
  final double topGap;
  final double rowGap;

  @override
  State<HomeReportsSection> createState() => _HomeReportsSectionState();
}

class _HomeReportsSectionState extends State<HomeReportsSection> {
  final CommunityService _communityService = CommunityService();
  List<CommunityModel> _entities = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = MainTabNavigation.maybeOf(context);
    if (nav == null || nav.currentIndex == MainTabNavigation.homeIndex) {
      _loadEntities();
    }
  }

  Future<void> _loadEntities() async {
    final entities = await _communityService.getMyEntityCommunities();
    if (!mounted) return;
    setState(() {
      _entities = entities;
      _loading = false;
    });
  }

  void _goToCommunities() {
    MainTabNavigation.maybeOf(context)?.goToTab(
      MainTabNavigation.communitiesIndex,
    );
  }

  Future<void> _openReportSheet(CommunityModel entity) async {
    final l10n = AppLocalizations.of(context)!;
    final id = entity.id;
    final name = entity.name;
    if (id == null) return;

    final sent = await ReportSendSheet.show(
      context,
      entityId: id,
      entityName: name,
      iconCodePoint: entity.iconCodePoint,
      iconColor: entity.iconColor,
      reportButtonColor: entity.reportButtonColor,
      allowedAlertTypes: parseEntityReportAlertTypes(entity),
    );
    if (!mounted || sent == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor:
            sent ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
        content: Text(
          sent ? l10n.reportSentSuccess : l10n.reportSentError,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: widget.topGap),
        Text(
          l10n.reportsSection,
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: widget.titleSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: widget.rowGap),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_entities.isEmpty)
          ReportsEmptyHomeShell(
            child: ReportsEmptyInline(
              line: l10n.reportsHomeEmptyLine,
              actionLabel: l10n.reportsHomeEmptyActionShort,
              onAction: _goToCommunities,
              semanticsLabel: l10n.reportsHomeEmptySemantics,
            ),
          )
        else
          EntityReportCardsStrip(
            entities: _entities,
            onReport: _openReportSheet,
          ),
      ],
    );
  }
}
