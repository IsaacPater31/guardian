import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/views/main_app/shared/main_tab_navigation.dart';
import 'package:guardian/views/main_app/widgets/report_send_sheet.dart';
import 'package:guardian/views/main_app/widgets/reports_empty_inline.dart';

/// Apartado **Reportes** en Home: acceso rápido para enviar reportes a las
/// entidades del usuario. Si no hay entidades vinculadas, muestra un mensaje
/// contextual (distinto al de la pestaña Comunidades).
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
  List<Map<String, dynamic>> _entities = [];
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

  Future<void> _openReportSheet(String entityId, String entityName) async {
    final l10n = AppLocalizations.of(context)!;
    final sent = await ReportSendSheet.show(
      context,
      entityId: entityId,
      entityName: entityName,
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
          _buildEntityStrip(l10n),
      ],
    );
  }

  Widget _buildEntityStrip(AppLocalizations l10n) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _entities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entity = _entities[index];
          final id = entity['id'] as String?;
          final name = (entity['name'] as String?) ?? '';
          if (id == null) return const SizedBox.shrink();

          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _openReportSheet(id, name),
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                width: 148,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF0D1B3E).withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.assignment_rounded,
                      color: Color(0xFF0D1B3E),
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.reportEntityTile(name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
