import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/features/communities/domain/community_model.dart';
import 'package:guardian/features/communities/application/community_service.dart';
import 'package:guardian/features/alerts/application/alert_service.dart';
import 'package:guardian/shared/domain/member_added_welcome_signal.dart';
import 'package:guardian/features/communities/presentation/community_feed_view.dart';
import 'package:guardian/features/communities/presentation/join_community_view.dart';
import 'package:guardian/features/communities/presentation/widgets/community_icon_picker.dart';
import 'package:guardian/features/entity_reports/presentation/widgets/reports_empty_inline.dart';

class ComunidadesView extends StatefulWidget {
  const ComunidadesView({super.key});

  @override
  State<ComunidadesView> createState() => _ComunidadesViewState();
}

class _ComunidadesViewState extends State<ComunidadesView>
    with SingleTickerProviderStateMixin {
  final CommunityService _communityService = CommunityService();
  final AlertService _alertService = AlertService();
  List<CommunityModel> _communities = [];

  /// Entidades (`is_entity`) del usuario — apartado "Reportes".
  List<CommunityModel> _entityCommunities = [];
  Map<String, int> _unreadByCommunity = {};
  bool _isLoading = true;
  String _searchQuery = '';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  StreamSubscription<MemberAddedWelcomeSignal>? _memberWelcomeSub;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadCommunities();
    _startMemberWelcomeListener();
  }

  @override
  void dispose() {
    _memberWelcomeSub?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _startMemberWelcomeListener() {
    _memberWelcomeSub?.cancel();
    _memberWelcomeSub =
        _communityService.watchMyMemberAddedWelcomes().listen((signal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            AppLocalizations.of(context)!
                .addedToCommunityBody(signal.displayName),
          ),
        ),
      );
      unawaited(
        _communityService.acknowledgeMemberAddedWelcome(signal.id),
      );
    });
  }

  Future<void> _loadCommunities() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final communities = await _communityService.getMyCommunities();
      final entities = await _communityService.getMyEntityCommunities();
      final unread = await _alertService.getUnreadCountByCommunity();
      if (!mounted) return;
      setState(() {
        _communities = communities;
        _entityCommunities = entities;
        _unreadByCommunity = unread;
        _isLoading = false;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      AppLogger.e('ComunidadesView._loadCommunities', e);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.communitiesLoadError,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF3B30),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.retry,
              textColor: Colors.white,
              onPressed: _loadCommunities,
            ),
          ),
        );
      }
    }
  }

  void _showCreateCommunityDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateCommunitySheet(
        onCommunityCreated: () {
          _loadCommunities();
        },
      ),
    );
  }

  List<CommunityModel> get _filteredCommunities {
    if (_searchQuery.trim().isEmpty) return _communities;
    final q = _searchQuery.trim().toLowerCase();
    return _communities
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  void _openJoinWithLink() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JoinCommunityView(),
      ),
    ).then((joined) {
      if (joined == true && mounted && context.mounted) {
        _loadCommunities();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              AppLocalizations.of(context)!.communities,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
            ),
            if (!_isLoading && _communities.isNotEmpty)
              Text(
                AppLocalizations.of(context)!.communityCount(_communities.length, _communities.length == 1 ? '' : 'es'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.link_rounded,
              color: Color(0xFF007AFF),
              size: 22,
            ),
            onPressed: _openJoinWithLink,
            tooltip: AppLocalizations.of(context)!.joinWithLink,
          ),
          IconButton(
            icon: const Icon(
              Icons.plus_one_rounded,
              color: Color(0xFF007AFF),
              size: 22,
            ),
            onPressed: _showCreateCommunityDialog,
            tooltip: AppLocalizations.of(context)!.createCommunity,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1F2937),
              ),
            )
          : FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildCommunitiesList(),
                ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showCreateCommunityDialog,
          backgroundColor: const Color(0xFF1C1C1E),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6,
            ),
            child: Text(
              AppLocalizations.of(context)!.createCommunity,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommunitiesList() {
    final communities = _filteredCommunities;

    return Column(
      children: [
        if (_communities.length > 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchCommunities,
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCommunities,
            color: const Color(0xFF007AFF),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                if (communities.isNotEmpty) ...[
                  _buildSectionHeader(AppLocalizations.of(context)!.myCommunities),
                  const SizedBox(height: 8),
                  _buildGroupedCards(communities),
                ] else ...[
                  _buildSectionHeader(AppLocalizations.of(context)!.myCommunities),
                  const SizedBox(height: 8),
                  _buildCommunitiesEmptyCard(),
                ],
                const SizedBox(height: 24),
                // Apartado "Reportes": siempre visible. Las entidades se agregan
                // solo por enlace/código de invitación.
                _buildSectionHeader(
                  AppLocalizations.of(context)!.reportsSection,
                ),
                const SizedBox(height: 8),
                if (_entityCommunities.isNotEmpty)
                  _buildGroupedEntityCards(_entityCommunities)
                else
                  _buildReportsEmptyCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunitiesEmptyCard() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            l10n.noCommunities,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.noCommunitiesAvailableEmptyState,
            style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Estado vacío del apartado Reportes — el usuario no está vinculado a
  /// ninguna entidad todavía.
  Widget _buildReportsEmptyCard() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ReportsEmptyInline(
        line: l10n.reportsEmptyLine,
        hint: l10n.reportsEmptyHint,
        actionLabel: l10n.reportsEmptyActionShort,
        onAction: _openJoinWithLink,
        semanticsLabel: l10n.reportsEmptySemantics,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildGroupedCards(List<CommunityModel> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildCommunityTile(items[i]),
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 72,
                color: Colors.grey[200],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommunityTile(CommunityModel community) {
    final communityId = community.id;
    final unreadCount = communityId != null
        ? (_unreadByCommunity[communityId] ?? 0)
        : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          final id = community.id!;
          final communityName = community.name;

          Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityFeedView(
                communityId: id,
                communityName: communityName,
              ),
            ),
          ).then((leftCommunity) {
            if (!mounted || !context.mounted) return;
            if (leftCommunity == true) {
              _loadCommunities();
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CommunityIconDisplay(
                iconCodePoint: community.iconCodePoint,
                iconColor: community.iconColor,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (community.description != null &&
                        community.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        community.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Trailing
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[350],
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedEntityCards(List<CommunityModel> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildEntityTile(items[i]),
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 72,
                color: Colors.grey[200],
              ),
          ],
        ],
      ),
    );
  }

  /// Tile de entidad — se muestra como "Reporte {Nombre}".
  Widget _buildEntityTile(CommunityModel entity) {
    final l10n = AppLocalizations.of(context)!;
    final entityId = entity.id;
    final entityName = entity.name;
    final unreadCount =
        entityId != null ? (_unreadByCommunity[entityId] ?? 0) : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (entityId == null) return;
          Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityFeedView(
                communityId: entityId,
                communityName: entityName,
              ),
            ),
          ).then((leftCommunity) {
            if (!mounted || !context.mounted) return;
            if (leftCommunity == true) {
              _loadCommunities();
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CommunityIconDisplay(
                iconCodePoint: entity.iconCodePoint,
                iconColor: entity.iconColor,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.reportEntityTile(entityName),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.entityReportLabel,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[350],
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bottom sheet para crear comunidad (reemplaza el AlertDialog)
// ─────────────────────────────────────────────────────────────
class _CreateCommunitySheet extends StatefulWidget {
  final VoidCallback onCommunityCreated;

  const _CreateCommunitySheet({required this.onCommunityCreated});

  @override
  State<_CreateCommunitySheet> createState() => _CreateCommunitySheetState();
}

class _CreateCommunitySheetState extends State<_CreateCommunitySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final CommunityService _communityService = CommunityService();
  bool _isCreating = false;
  int? _selectedIconCodePoint;
  String? _selectedIconColor;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createCommunity() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    try {
      final communityId = await _communityService.createCommunity(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        iconCodePoint: _selectedIconCodePoint,
        iconColor: _selectedIconColor,
      );

      if (communityId != null && mounted) {
        Navigator.pop(context);
        widget.onCommunityCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.communityCreatedSuccess,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF34C759),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.errorCreatingCommunity,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFFF3B30),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorOccurred),
            backgroundColor: const Color(0xFFFF3B30),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF007AFF),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.createNewCommunity,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Fields
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    _buildInputLabel(AppLocalizations.of(context)!.communityNameRequired),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isCreating,
                      style: const TextStyle(fontSize: 15),
                      decoration: _inputDecoration(
                        hint: AppLocalizations.of(context)!.communityNameHint,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context)!.nameRequired;
                        }
                        if (value.trim().length < 3) {
                          return AppLocalizations.of(context)!.nameMinLength;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Description
                    _buildInputLabel(AppLocalizations.of(context)!.descriptionOptional),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_isCreating,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 15),
                      decoration: _inputDecoration(
                        hint: AppLocalizations.of(context)!.descriptionHint,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Icon picker
                    CommunityIconPickerGrid(
                      selectedCodePoint: _selectedIconCodePoint,
                      selectedColor: _selectedIconColor,
                      onIconSelected: _isCreating
                          ? (_) {}
                          : (option) {
                              setState(() {
                                _selectedIconCodePoint = option.codePoint;
                                _selectedIconColor = option.colorHex;
                              });
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _isCreating ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.cancel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isCreating ? null : _createCommunity,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C1C1E),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF1C1C1E).withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                AppLocalizations.of(context)!.create,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
        letterSpacing: -0.1,
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
      filled: true,
      fillColor: const Color(0xFFF8F8FA),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF007AFF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFFFF3B30), width: 1),
      ),
    );
  }
}
