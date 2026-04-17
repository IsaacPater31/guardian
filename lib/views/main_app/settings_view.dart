import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/services/quick_alert_config_service.dart';
import 'package:guardian/services/swipe_alert_config_service.dart';
import 'package:guardian/models/emergency_types.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kBg = Color(0xFFF2F2F7);         // iOS system grouped background
const _kCard = Color(0xFFFFFFFF);
const _kPrimary = Color(0xFF1C1C1E);    // iOS label
const _kSecondary = Color(0xFF636366);  // iOS secondary label
const _kSeparator = Color(0xFFD1D1D6); // iOS separator
const _kBlue = Color(0xFF007AFF);       // iOS blue
const _kGreen = Color(0xFF30D158);      // iOS green
const _kOrange = Color(0xFFFF9F0A);     // iOS orange
const _kRed = Color(0xFFFF3B30);        // iOS red

// =============================================================================
// SettingsView
// =============================================================================
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _AppleAppBar(title: l10n.settingsTitle),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          _SectionLabel(l10n.alertsSection.toUpperCase()),
          _AppleCard(
            children: [
              _AppleTile(
                icon: Icons.bolt_rounded,
                iconColor: _kOrange,
                title: 'Alertas Rápidas',
                subtitle: 'Comunidades que reciben el toque de emergencia',
                onTap: () => Navigator.push(context,
                    _slide(const QuickAlertConfigView())),
              ),
              const _CardDivider(),
              _AppleTile(
                icon: Icons.swipe_rounded,
                iconColor: _kBlue,
                title: 'Alertas por Tipo',
                subtitle: 'Destinos predeterminados por cada tipo de alerta',
                onTap: () => Navigator.push(context,
                    _slide(const SwipeAlertConfigView())),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _SectionLabel(l10n.generalSection.toUpperCase()),
          _AppleCard(
            children: [
              _AppleTile(
                icon: Icons.info_rounded,
                iconColor: _kSecondary,
                title: l10n.about,
                subtitle: 'Versión 1.0 · Guardian',
                showChevron: false,
                onTap: null,
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// =============================================================================
// QuickAlertConfigView — rediseño Apple
// =============================================================================
class QuickAlertConfigView extends StatefulWidget {
  const QuickAlertConfigView({super.key});

  @override
  State<QuickAlertConfigView> createState() => _QuickAlertConfigViewState();
}

class _QuickAlertConfigViewState extends State<QuickAlertConfigView>
    with SingleTickerProviderStateMixin {
  final QuickAlertConfigService _configService = QuickAlertConfigService();
  List<Map<String, dynamic>> _destinations = [];
  Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  late final AnimationController _saveAnim;

  @override
  void initState() {
    super.initState();
    _saveAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
    _loadConfiguration();
  }

  @override
  void dispose() {
    _saveAnim.dispose();
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    setState(() => _isLoading = true);
    try {
      final destinations = await _configService.getAvailableDestinations();
      final currentConfig = await _configService.getQuickAlertDestinations();
      if (mounted) {
        setState(() {
          _destinations = destinations;
          _selectedIds = currentConfig.toSet();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    final success =
        await _configService.updateQuickAlertDestinations(_selectedIds.toList());
    if (mounted) {
      setState(() => _isSaving = false);
      _showSaveToast(success);
    }
  }

  void _showSaveToast(bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: success ? _kPrimary : _kRed,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              success ? 'Configuración guardada' : 'Error al guardar',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entities = _destinations.where((d) => d['is_entity'] == true).toList();
    final communities = _destinations.where((d) => d['is_entity'] != true).toList();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _AppleAppBar(title: 'Alertas Rápidas', actions: [
        if (!_isLoading)
          _NavBarAction(
            label: 'Guardar',
            loading: _isSaving,
            onTap: _save,
          ),
      ]),
      body: _isLoading
          ? const _Loader()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: _InfoBanner(
                      icon: Icons.bolt_rounded,
                      color: _kOrange,
                      text:
                          'Al presionar el botón de emergencia, la alerta se enviará instantáneamente a las comunidades seleccionadas.',
                    ),
                  ),
                ),
                if (entities.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionLabel('ENTIDADES OFICIALES',
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6)),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _AppleCard(
                        children: entities
                            .asMap()
                            .entries
                            .map((entry) {
                              final d = entry.value;
                              final isLast = entry.key == entities.length - 1;
                              return Column(
                                children: [
                                  _CommunityCheckTile(
                                    community: d,
                                    isSelected:
                                        _selectedIds.contains(d['id'] as String),
                                    onChanged: (val) => setState(() {
                                      val == true
                                          ? _selectedIds.add(d['id'] as String)
                                          : _selectedIds
                                              .remove(d['id'] as String);
                                    }),
                                  ),
                                  if (!isLast) const _CardDivider(),
                                ],
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ),
                ],
                if (communities.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionLabel('MIS COMUNIDADES',
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 6)),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _AppleCard(
                        children: communities
                            .asMap()
                            .entries
                            .map((entry) {
                              final d = entry.value;
                              final isLast = entry.key == communities.length - 1;
                              return Column(
                                children: [
                                  _CommunityCheckTile(
                                    community: d,
                                    isSelected:
                                        _selectedIds.contains(d['id'] as String),
                                    onChanged: (val) => setState(() {
                                      val == true
                                          ? _selectedIds.add(d['id'] as String)
                                          : _selectedIds
                                              .remove(d['id'] as String);
                                    }),
                                  ),
                                  if (!isLast) const _CardDivider(),
                                ],
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ),
                ],
                if (_destinations.isEmpty)
                  const SliverFillRemaining(
                    child: _EmptyState(
                      icon: Icons.group_off_rounded,
                      message: 'No tienes comunidades disponibles.\nÚnete o crea una para comenzar.',
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }
}

// =============================================================================
// SwipeAlertConfigView — rediseño Apple
// =============================================================================
class SwipeAlertConfigView extends StatefulWidget {
  final String? initialAlertType;
  const SwipeAlertConfigView({super.key, this.initialAlertType});

  @override
  State<SwipeAlertConfigView> createState() => _SwipeAlertConfigViewState();
}

class _SwipeAlertConfigViewState extends State<SwipeAlertConfigView> {
  final SwipeAlertConfigService _configService = SwipeAlertConfigService();
  List<Map<String, dynamic>> _communities = [];
  final Map<String, Set<String>> _selectedByType = {};
  bool _isLoading = true;
  bool _isSaving = false;
  // Track which type is expanded
  String? _expandedType;

  @override
  void initState() {
    super.initState();
    _expandedType = widget.initialAlertType;
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final communities = await _configService.getAvailableCommunities();
      final Map<String, Set<String>> byType = {};
      for (final alertType in EmergencyTypes.allTypes) {
        final saved = await _configService.getCommunitiesForType(alertType);
        byType[alertType] = saved != null ? saved.toSet() : {};
      }
      if (mounted) {
        setState(() {
          _communities = communities;
          _selectedByType.addAll(byType);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAll() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    int saved = 0;
    for (final entry in _selectedByType.entries) {
      final ok = await _configService.setCommunitiesForType(
          entry.key, entry.value.toList());
      if (ok) saved++;
    }
    if (mounted) {
      setState(() => _isSaving = false);
      final success = saved == _selectedByType.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: success ? _kPrimary : _kOrange,
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                success ? 'Configuración guardada' : 'Algunos tipos no se guardaron',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = EmergencyTypes.types.entries.toList();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _AppleAppBar(title: 'Alertas por Tipo', actions: [
        if (!_isLoading)
          _NavBarAction(
            label: 'Guardar',
            loading: _isSaving,
            onTap: _saveAll,
          ),
      ]),
      body: _isLoading
          ? const _Loader()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: _InfoBanner(
                      icon: Icons.swipe_rounded,
                      color: _kBlue,
                      text:
                          'Define a qué comunidades se enviará cada tipo de alerta cuando arrastres el botón. Si no configuras un tipo, se te pedirá al enviar.',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SectionLabel('TIPOS DE ALERTA',
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = types[index];
                        final typeData = entry.value;
                        final typeName = typeData['type'] as String;
                        final color = typeData['color'] as Color;
                        final icon = typeData['icon'] as IconData;
                        final label =
                            EmergencyTypes.getTranslatedType(typeName, context);
                        final selected = _selectedByType[typeName] ?? {};
                        final isHighlighted = widget.initialAlertType == typeName;
                        final isExpanded = _expandedType == typeName;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AlertTypeCard(
                            typeName: typeName,
                            label: label,
                            color: color,
                            icon: icon,
                            selected: selected,
                            communities: _communities,
                            isHighlighted: isHighlighted,
                            isExpanded: isExpanded,
                            onExpansionChanged: (val) => setState(() {
                              _expandedType = val ? typeName : null;
                            }),
                            onToggleCommunity: (communityId, val) {
                              setState(() {
                                final set = Set<String>.from(
                                    _selectedByType[typeName] ?? {});
                                val ? set.add(communityId) : set.remove(communityId);
                                _selectedByType[typeName] = set;
                              });
                            },
                          ),
                        );
                      },
                      childCount: types.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }
}

// =============================================================================
// Shared reusable components
// =============================================================================

/// iOS-style app bar (no elevation, white background)
class _AppleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const _AppleAppBar({required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _kCard,
      foregroundColor: _kPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: _kSeparator,
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: _kPrimary,
        ),
      ),
      iconTheme: const IconThemeData(color: _kBlue),
      actions: actions,
    );
  }
}

/// iOS-style nav bar text button (like "Done" / "Save")
class _NavBarAction extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _NavBarAction({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onPressed: loading ? null : onTap,
      child: loading
          ? const CupertinoActivityIndicator()
          : Text(
              label,
              style: const TextStyle(
                color: _kBlue,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

/// iOS grouped section heading
class _SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;

  const _SectionLabel(this.text,
      {this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 6)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _kSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// White card container for grouped rows
class _AppleCard extends StatelessWidget {
  final List<Widget> children;
  const _AppleCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

/// iOS-style list tile with icon badge
class _AppleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool showChevron;
  final VoidCallback? onTap;

  const _AppleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _kPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _kSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                const Icon(Icons.chevron_right_rounded,
                    color: _kSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin separator inside cards
class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 62),
      child: Divider(height: 1, color: _kSeparator),
    );
  }
}

/// Colored info banner (used at top of config screens)
class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBanner(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: color.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Community toggle row used in QuickAlertConfigView
class _CommunityCheckTile extends StatelessWidget {
  final Map<String, dynamic> community;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  const _CommunityCheckTile({
    required this.community,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final name = community['name'] as String? ?? '';
    final isEntity = community['is_entity'] as bool? ?? false;
    final color = isEntity ? _kBlue : _kGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!isSelected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEntity ? Icons.shield_rounded : Icons.group_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _kPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (isEntity)
                      const SizedBox(height: 2),
                    if (isEntity)
                      Text(
                        'Entidad Oficial',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kBlue.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              // iOS-style toggle
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? _kBlue : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _kBlue : _kSeparator,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alert type card with expandable community list (SwipeAlertConfigView)
class _AlertTypeCard extends StatelessWidget {
  final String typeName;
  final String label;
  final Color color;
  final IconData icon;
  final Set<String> selected;
  final List<Map<String, dynamic>> communities;
  final bool isHighlighted;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final void Function(String communityId, bool selected) onToggleCommunity;

  const _AlertTypeCard({
    required this.typeName,
    required this.label,
    required this.color,
    required this.icon,
    required this.selected,
    required this.communities,
    required this.isHighlighted,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onToggleCommunity,
  });

  @override
  Widget build(BuildContext context) {
    final hasConfig = selected.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: isHighlighted
            ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isHighlighted ? 0.08 : 0.04),
            blurRadius: isHighlighted ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Header row
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onExpansionChanged(!isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Color icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _kPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Status badge
                            hasConfig
                                ? _StatusBadge(
                                    text:
                                        '${selected.length} comunidad${selected.length != 1 ? 'es' : ''}',
                                    color: _kGreen,
                                  )
                                : _StatusBadge(
                                    text: 'Sin configurar',
                                    color: _kOrange,
                                  ),
                          ],
                        ),
                      ),
                      // Animated chevron
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.chevron_right_rounded,
                            color: _kSecondary, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Expandable community list
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              firstCurve: Curves.easeInOut,
              secondCurve: Curves.easeInOut,
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  Divider(
                      height: 1,
                      color: color.withValues(alpha: 0.15),
                      indent: 0,
                      endIndent: 0),
                  if (communities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No tienes comunidades disponibles',
                        style: TextStyle(color: _kSecondary, fontSize: 14),
                      ),
                    )
                  else
                    ...communities.asMap().entries.map((entry) {
                      final i = entry.key;
                      final community = entry.value;
                      final id = community['id'] as String;
                      final isEntity =
                          community['is_entity'] as bool? ?? false;
                      final communityColor = isEntity ? _kBlue : _kGreen;
                      final isSel = selected.contains(id);

                      return Column(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onToggleCommunity(id, !isSel),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: communityColor
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isEntity
                                            ? Icons.shield_rounded
                                            : Icons.group_rounded,
                                        color: communityColor,
                                        size: 17,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        community['name'] as String? ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: _kPrimary,
                                        ),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: isSel ? color : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSel ? color : _kSeparator,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSel
                                          ? const Icon(Icons.check_rounded,
                                              color: Colors.white, size: 13)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (i < communities.length - 1)
                            const Padding(
                              padding: EdgeInsets.only(left: 60),
                              child: Divider(
                                  height: 1, color: _kSeparator),
                            ),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill badge
class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Loading indicator
class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CupertinoActivityIndicator(radius: 14),
    );
  }
}

/// Empty state illustration
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kSecondary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: _kSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: _kSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page route with iOS slide transition
PageRoute<T> _slide<T>(Widget page) => CupertinoPageRoute(builder: (_) => page);
