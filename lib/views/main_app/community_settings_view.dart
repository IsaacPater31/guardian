import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardian/core/app_logger.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/community_repository.dart';
import 'package:guardian/models/community_model.dart';
import 'package:guardian/views/main_app/community_members_view.dart';
import 'package:guardian/views/main_app/community_reports_view.dart';
import 'package:guardian/views/main_app/widgets/community_icon_picker.dart';

class CommunitySettingsView extends StatefulWidget {
  final String communityId;
  final String userRole; // 'admin' o 'member'

  const CommunitySettingsView({
    super.key,
    required this.communityId,
    required this.userRole,
  });

  @override
  State<CommunitySettingsView> createState() => _CommunitySettingsViewState();
}

class _CommunitySettingsViewState extends State<CommunitySettingsView> {
  final CommunityService _communityService = CommunityService();
  final CommunityRepository _communityRepository = CommunityRepository();
  CommunityModel? _community;
  bool _isLoading = true;
  bool _isGeneratingLink = false;
  int _pendingReportsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  Future<void> _loadCommunity() async {
    setState(() => _isLoading = true);
    try {
      final community =
          await _communityRepository.getCommunityById(widget.communityId);
      int reportsCount = 0;
      if (widget.userRole == 'admin') {
        reportsCount = await _communityService
            .getPendingReportsCount(widget.communityId);
      }
      setState(() {
        _community = community;
        _pendingReportsCount = reportsCount;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.e('CommunitySettingsView._loadCommunity', e);
      setState(() => _isLoading = false);
    }
  }

  // ─── Snackbar helpers ─────────────────────────────────────
  void _showSnackBar(String message,
      {required bool isSuccess, IconData? icon}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ??
                  (isSuccess
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor:
            isSuccess ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Edit Community ───────────────────────────────────────
  void _showEditCommunityDialog() {
    final nameController =
        TextEditingController(text: _community?.name ?? '');
    final descriptionController =
        TextEditingController(text: _community?.description ?? '');
    final formKey = GlobalKey<FormState>();
    bool isUpdating = false;
    int? selectedIconCodePoint = _community?.iconCodePoint;
    String? selectedIconColor = _community?.iconColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Color(0xFF007AFF),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.editCommunity,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E),
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputLabel(AppLocalizations.of(context)!.communityNameLabel),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameController,
                          enabled: !isUpdating,
                          style: const TextStyle(fontSize: 15),
                          decoration: _inputDecoration(
                              hint: AppLocalizations.of(context)!.communityNameLabel),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return AppLocalizations.of(context)!.nameRequired;
                            }
                            if (value.trim().length < 3) {
                              return AppLocalizations.of(context)!.minChars;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildInputLabel(AppLocalizations.of(context)!.descriptionOptional),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: descriptionController,
                          enabled: !isUpdating,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 15),
                          decoration:
                              _inputDecoration(hint: AppLocalizations.of(context)!.describeYourCommunity),
                        ),
                        const SizedBox(height: 18),
                        _buildInputLabel(AppLocalizations.of(context)!.communityIcon),
                        const SizedBox(height: 6),
                        CommunityIconPickerGrid(
                          selectedCodePoint: selectedIconCodePoint,
                          selectedColor: selectedIconColor,
                          onIconSelected: isUpdating
                              ? (_) {}
                              : (option) {
                                  setSheetState(() {
                                    selectedIconCodePoint = option.codePoint;
                                    selectedIconColor = option.colorHex;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isUpdating
                                ? null
                                : () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(AppLocalizations.of(context)!.cancel,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isUpdating
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setSheetState(() => isUpdating = true);
                                    final newName =
                                        nameController.text.trim();
                                    final newDescription =
                                        descriptionController.text.trim();
                                    final success =
                                        await _communityService
                                            .updateCommunity(
                                      widget.communityId,
                                      name: newName,
                                      description: newDescription.isEmpty
                                          ? null
                                          : newDescription,
                                      iconCodePoint: selectedIconCodePoint,
                                      iconColor: selectedIconColor,
                                    );
                                    if (mounted) {
                                      Navigator.pop(context);
                                      if (success) {
                                        setState(() {
                                          _community =
                                              _community!.copyWith(
                                            name: newName,
                                            description:
                                                newDescription.isEmpty
                                                    ? null
                                                    : newDescription,
                                            iconCodePoint: selectedIconCodePoint,
                                            iconColor: selectedIconColor,
                                          );
                                        });
                                        _showSnackBar(
                                            AppLocalizations.of(context)!.communityUpdated,
                                            isSuccess: true);
                                      } else {
                                        _showSnackBar(
                                            AppLocalizations.of(context)!.errorUpdatingCommunity,
                                            isSuccess: false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1C1C1E),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF1C1C1E)
                                  .withValues(alpha: 0.5),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isUpdating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                    ),
                                  )
                                : Text(AppLocalizations.of(context)!.save,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                    )),
                          ),
                        ),
                      ],
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

  // ─── Invite Link ──────────────────────────────────────────
  Future<void> _generateInviteLink() async {
    setState(() => _isGeneratingLink = true);
    try {
      final link =
          await _communityService.generateInviteLink(widget.communityId);
      if (link != null) {
        setState(() => _isGeneratingLink = false);
        _showInviteLinkSheet(link);
      } else {
        setState(() => _isGeneratingLink = false);
        _showSnackBar(AppLocalizations.of(context)!.errorGeneratingLink, isSuccess: false);
      }
    } catch (e) {
      setState(() => _isGeneratingLink = false);
      _showSnackBar('Error: $e', isSuccess: false);
    }
  }

  void _showInviteLinkSheet(String link) {
    final communityName = _community?.name ?? 'la comunidad';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.link_rounded,
                      color: Color(0xFF34C759),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Link de Invitación',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.shareInviteLinkText,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: SelectableText(
                      'https://$link',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.linkExpiresHours,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: 'https://$link'));
                        Navigator.pop(context);
                        _showSnackBar(AppLocalizations.of(context)!.linkCopied,
                            isSuccess: true, icon: Icons.copy_rounded);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copiar',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1C1C1E),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Share.share(
                          '${AppLocalizations.of(context)!.joinCommunityShareText(communityName)}\n\nhttps://$link',
                          subject:
                              AppLocalizations.of(context)!.invitationTo(communityName),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Compartir',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }

  // ─── Admin options ────────────────────────────────────────
  Future<void> _updateAllowForward(bool value) async {
    if (_community == null) return;
    try {
      final success = await _communityService.updateCommunity(
        widget.communityId,
        allowForwardToEntities: value,
      );
      if (success) {
        setState(() {
          _community = _community!.copyWith(allowForwardToEntities: value);
        });
        _showSnackBar(
          value
              ? 'Reenvío a entidades habilitado'
              : 'Reenvío a entidades deshabilitado',
          isSuccess: true,
        );
      } else {
        _showSnackBar('Solo el creador puede modificar la configuración',
            isSuccess: false);
      }
    } catch (e) {
      _showSnackBar('Error actualizando configuración', isSuccess: false);
    }
  }

  Future<void> _deleteCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red[400], size: 22),
            const SizedBox(width: 8),
            const Text(
              'Eliminar Comunidad',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta acción es irreversible y eliminará:',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildBullet('Todos los miembros'),
            _buildBullet('Todas las invitaciones'),
            _buildBullet('La comunidad por completo'),
            const SizedBox(height: 12),
            Text(
              'Las alertas enviadas permanecerán en el historial.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(
                  color: Color(0xFFFF3B30), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _showLoadingOverlay();
      final success =
          await _communityService.deleteCommunity(widget.communityId);
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        if (success) {
          Navigator.pop(context);
          Navigator.pop(context);
          _showSnackBar(AppLocalizations.of(context)!.communityDeleted, isSuccess: true);
        } else {
          _showSnackBar(AppLocalizations.of(context)!.errorDeletingCommunity, isSuccess: false);
        }
      }
    }
  }

  Future<void> _leaveCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Abandonar Comunidad',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        content: Text(
          '¿Estás seguro? No podrás ver las alertas ni participar en ella.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[700],
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Abandonar',
              style: TextStyle(
                  color: Color(0xFFFF3B30), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success =
            await _communityService.leaveCommunity(widget.communityId);
        if (mounted && success) {
          _showSnackBar(AppLocalizations.of(context)!.leftCommunity,
              isSuccess: true, icon: Icons.exit_to_app_rounded);
          // Señal al feed para cerrar la comunidad y volver al listado actualizado.
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          final msg = e.toString().replaceFirst('Exception: ', '');
          _showSnackBar(msg, isSuccess: false);
        }
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF1F2937),
          ),
        ),
      );
    }

    if (_community == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 36, color: Color(0xFFFF3B30)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Error cargando comunidad',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isAdmin = widget.userRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ─── Community Header ─────────────────────────
          _buildHeaderCard(isAdmin),
          const SizedBox(height: 24),

          // ─── Community Section ────────────────────────
          _buildSectionHeader(AppLocalizations.of(context)!.communitySection),
          const SizedBox(height: 8),
          _buildGroupedCard([
            _buildSettingsTile(
              icon: Icons.people_outline_rounded,
              iconColor: const Color(0xFF007AFF),
              title: AppLocalizations.of(context)!.viewMembers,
              subtitle: 'Todos los integrantes',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityMembersView(
                      communityId: widget.communityId,
                      communityName: _community?.name ?? '',
                      userRole: widget.userRole,
                    ),
                  ),
                ).then((_) {
                  if (mounted) _loadCommunity();
                });
              },
            ),
            if (isAdmin)
              _buildSettingsTile(
                icon: Icons.flag_outlined,
                iconColor: _pendingReportsCount > 0
                    ? const Color(0xFFFF9500)
                    : const Color(0xFF8E8E93),
                title: AppLocalizations.of(context)!.reports,
                subtitle: _pendingReportsCount > 0
                    ? AppLocalizations.of(context)!.pendingCount(_pendingReportsCount, _pendingReportsCount > 1 ? 's' : '')
                    : AppLocalizations.of(context)!.noPendingReports,
                badge: _pendingReportsCount > 0 ? _pendingReportsCount : null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityReportsView(
                        communityId: widget.communityId,
                        communityName: _community?.name ?? '',
                      ),
                    ),
                  );
                  _loadCommunity();
                },
              ),
          ]),
          const SizedBox(height: 24),

          // ─── Invite Section ───────────────────────────
          _buildSectionHeader(AppLocalizations.of(context)!.addMembersSection),
          const SizedBox(height: 8),
          _buildGroupedCard([
            if (isAdmin)
              _buildSettingsTile(
                icon: Icons.person_search_rounded,
                iconColor: const Color(0xFF34C759),
                title: 'Buscar y agregar',
                subtitle: 'Agrega miembros por email o nombre',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityMembersView(
                        communityId: widget.communityId,
                        communityName: _community?.name ?? '',
                        userRole: widget.userRole,
                        autoOpenAddSheet: true,
                      ),
                    ),
                  ).then((_) {
                    if (mounted) _loadCommunity();
                  });
                },
              ),
            _buildSettingsTile(
              icon: Icons.link_rounded,
              iconColor: const Color(0xFF007AFF),
              title: 'Generar link de invitación',
              subtitle: _isGeneratingLink
                  ? AppLocalizations.of(context)!.generating
                  : AppLocalizations.of(context)!.shareToInvite,
              trailing: _isGeneratingLink
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF007AFF),
                      ),
                    )
                  : null,
              onTap: _isGeneratingLink ? null : _generateInviteLink,
            ),
          ]),
          const SizedBox(height: 24),

          // ─── Admin Section ────────────────────────────
          if (isAdmin) ...[
            _buildSectionHeader('ADMINISTRACIÓN'),
            const SizedBox(height: 8),
            _buildGroupedCard([
              _buildSwitchTile(
                icon: Icons.reply_all_rounded,
                iconColor: const Color(0xFF5856D6),
                title: 'Reenvío a entidades',
                subtitle: 'Alertas pueden reenviarse a entidades oficiales',
                value: _community!.allowForwardToEntities,
                onChanged: _updateAllowForward,
              ),
            ]),
            const SizedBox(height: 24),
          ],

          // ─── Danger Zone ──────────────────────────────
          _buildSectionHeader(AppLocalizations.of(context)!.dangerZone),
          const SizedBox(height: 8),
          _buildGroupedCard([
            if (isAdmin)
              _buildSettingsTile(
                icon: Icons.delete_forever_rounded,
                iconColor: const Color(0xFFFF3B30),
                title: 'Eliminar comunidad',
                subtitle: 'Elimina permanentemente',
                titleColor: const Color(0xFFFF3B30),
                onTap: _deleteCommunity,
              ),
            _buildSettingsTile(
              icon: Icons.exit_to_app_rounded,
              iconColor: const Color(0xFFFF9500),
              title: 'Abandonar comunidad',
              subtitle: 'Dejarás de recibir alertas',
              titleColor: const Color(0xFFFF9500),
              onTap: _leaveCommunity,
            ),
          ]),
        ],
      ),
    );
  }

  // ─── Reusable Widgets ─────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF2F2F7),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Configuración',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1C1E),
          letterSpacing: -0.3,
        ),
      ),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: Color(0xFF007AFF),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          CommunityIconDisplay(
            iconCodePoint: _community!.iconCodePoint,
            iconColor: _community!.iconColor,
            isEntity: _community!.isEntity,
            size: 52,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _community!.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.4,
                  ),
                ),
                if (_community!.description != null &&
                    _community!.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _community!.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (isAdmin)
            GestureDetector(
              onTap: _showEditCommunityDialog,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: Color(0xFF007AFF),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(List<Widget> children) {
    // Filter out any null-like gaps
    final validChildren = children;
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
          for (int i = 0; i < validChildren.length; i++) ...[
            validChildren[i],
            if (i < validChildren.length - 1)
              Divider(height: 1, indent: 60, color: Colors.grey[200]),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color? titleColor,
    Widget? trailing,
    int? badge,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? const Color(0xFF1C1C1E),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              trailing ??
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.grey[350], size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
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
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF34C759),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[500],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        ],
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
