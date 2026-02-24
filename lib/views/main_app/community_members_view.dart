import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guardian/services/community_service.dart';

/// Vista de miembros de una comunidad con diseño premium Apple-inspired.
/// Todos pueden ver miembros; admins pueden promover, expulsar y reportar.
class CommunityMembersView extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String userRole;

  const CommunityMembersView({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.userRole,
  });

  @override
  State<CommunityMembersView> createState() => _CommunityMembersViewState();
}

class _CommunityMembersViewState extends State<CommunityMembersView>
    with SingleTickerProviderStateMixin {
  final CommunityService _communityService = CommunityService();
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isAdmin => widget.userRole == 'admin';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadMembers();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members =
          await _communityService.getCommunityMembers(widget.communityId);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
        _fadeController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Admin Actions ───

  Future<void> _promoteToAdmin(Map<String, dynamic> member) async {
    final confirmed = await _showConfirmDialog(
      title: 'Promover a Administrador',
      message:
          '¿Quieres hacer administrador a ${member['user_name']}? Podrá gestionar miembros y la configuración de la comunidad.',
      confirmText: 'Promover',
      confirmColor: const Color(0xFF007AFF),
    );

    if (confirmed != true) return;

    _showLoadingOverlay();
    final success = await _communityService.promoteToAdmin(
      widget.communityId,
      member['user_id'],
    );
    if (mounted) Navigator.pop(context); // dismiss loading

    if (success) {
      _showSnackBar('${member['user_name']} ahora es administrador',
          isSuccess: true);
      _loadMembers();
    } else {
      _showSnackBar('Error al promover miembro', isSuccess: false);
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final confirmed = await _showConfirmDialog(
      title: 'Expulsar Miembro',
      message:
          '¿Estás seguro de que quieres expulsar a ${member['user_name']}? No podrá ver alertas de esta comunidad.',
      confirmText: 'Expulsar',
      confirmColor: Colors.red,
      isDestructive: true,
    );

    if (confirmed != true) return;

    _showLoadingOverlay();
    final success = await _communityService.removeMember(
      widget.communityId,
      member['user_id'],
    );
    if (mounted) Navigator.pop(context); // dismiss loading

    if (success) {
      _showSnackBar('${member['user_name']} ha sido expulsado',
          isSuccess: true);
      _loadMembers();
    } else {
      _showSnackBar('No se pudo expulsar al miembro', isSuccess: false);
    }
  }

  Future<void> _reportMember(Map<String, dynamic> member) async {
    final reason = await _showReportDialog(member['user_name']);
    if (reason == null || reason.trim().isEmpty) return;

    _showLoadingOverlay();
    final success = await _communityService.reportMember(
      communityId: widget.communityId,
      reportedUserId: member['user_id'],
      reason: reason.trim(),
    );
    if (mounted) Navigator.pop(context); // dismiss loading

    if (success) {
      _showSnackBar('Reporte enviado a los administradores', isSuccess: true);
    } else {
      _showSnackBar('Error al enviar el reporte', isSuccess: false);
    }
  }

  // ─── Dialogs ───

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        content: Text(
          message,
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
              'Cancelar',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: confirmColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showReportDialog(String userName) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reportar a $userName',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Describe el motivo del reporte. Un administrador revisará tu solicitud.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Escribe el motivo del reporte...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF007AFF),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text(
              'Enviar Reporte',
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

  void _showSnackBar(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Bottom Sheet Actions ───

  void _showMemberActions(Map<String, dynamic> member) {
    final isCurrentUser = member['user_id'] == _currentUserId;
    final memberRole = member['role'] as String;
    final memberName = member['user_name'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle indicator
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Member header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    _buildAvatar(memberName, memberRole, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memberName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (member['user_email'].toString().isNotEmpty)
                            Text(
                              member['user_email'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildRoleBadge(memberRole),
                  ],
                ),
              ),
              Divider(color: Colors.grey[100], height: 1),
              // Actions
              if (!isCurrentUser) ...[
                // Admin actions
                if (_isAdmin && memberRole != 'admin') ...[
                  _buildActionTile(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF007AFF),
                    title: 'Hacer Administrador',
                    subtitle: 'Dar permisos de gestión',
                    onTap: () {
                      Navigator.pop(context);
                      _promoteToAdmin(member);
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.person_remove_outlined,
                    iconColor: const Color(0xFFFF3B30),
                    title: 'Expulsar',
                    subtitle: 'Remover de la comunidad',
                    onTap: () {
                      Navigator.pop(context);
                      _removeMember(member);
                    },
                  ),
                ],
                // Report (available for everyone)
                _buildActionTile(
                  icon: Icons.flag_outlined,
                  iconColor: const Color(0xFFFF9500),
                  title: 'Reportar',
                  subtitle: 'Enviar reporte a los administradores',
                  onTap: () {
                    Navigator.pop(context);
                    _reportMember(member);
                  },
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Este eres tú',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build Helpers ───

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
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
                      letterSpacing: -0.2,
                    ),
                  ),
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
            Icon(Icons.chevron_right, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String role, {double size = 40}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isAdminRole = role == 'admin';
    final gradientColors = isAdminRole
        ? [const Color(0xFF667EEA), const Color(0xFF764BA2)]
        : [const Color(0xFF868E96), const Color(0xFFADB5BD)];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final isAdmin = role == 'admin';
    final isOfficial = role == 'official';
    final label = isAdmin
        ? 'Admin'
        : isOfficial
            ? 'Oficial'
            : 'Miembro';
    final bgColor = isAdmin
        ? const Color(0xFF007AFF).withValues(alpha: 0.1)
        : isOfficial
            ? const Color(0xFFFF9500).withValues(alpha: 0.1)
            : Colors.grey[100]!;
    final textColor = isAdmin
        ? const Color(0xFF007AFF)
        : isOfficial
            ? const Color(0xFFFF9500)
            : Colors.grey[600]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS system background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'Miembros',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
            ),
            if (!_isLoading)
              Text(
                '${_members.length} ${_members.length == 1 ? 'miembro' : 'miembros'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF007AFF),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1F2937),
              ),
            )
          : _members.isEmpty
              ? _buildEmptyState()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: _loadMembers,
                    color: const Color(0xFF007AFF),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: _members.length + 1, // +1 for section header
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildSectionHeader();
                        }
                        final member = _members[index - 1];
                        final isLast = index == _members.length;
                        return _buildMemberTile(member, isFirst: index == 1, isLast: isLast);
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionHeader() {
    final adminCount = _members.where((m) => m['role'] == 'admin').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Text(
            widget.communityName.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (adminCount > 0)
            Text(
              '$adminCount admin${adminCount > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF007AFF).withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member,
      {required bool isFirst, required bool isLast}) {
    final name = member['user_name'] as String;
    final email = member['user_email'] as String;
    final role = member['role'] as String;
    final isCurrentUser = member['user_id'] == _currentUserId;

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(12) : Radius.zero,
          bottom: isLast ? const Radius.circular(12) : Radius.zero,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showMemberActions(member),
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(12) : Radius.zero,
              bottom: isLast ? const Radius.circular(12) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildAvatar(name, role),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1C1C1E),
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(tú)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildRoleBadge(role),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[300],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 70),
              child: Divider(
                height: 0.5,
                thickness: 0.5,
                color: Colors.grey[200],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 36,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin miembros',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No se encontraron miembros en esta comunidad',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
