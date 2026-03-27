import 'dart:async';
import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guardian/services/community_service.dart';

/// Vista de miembros de una comunidad con diseño premium Apple-inspired.
/// Todos pueden ver miembros; admins pueden promover, expulsar y reportar.
class CommunityMembersView extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String userRole;
  final bool autoOpenAddSheet;

  const CommunityMembersView({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.userRole,
    this.autoOpenAddSheet = false,
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
    _loadMembers().then((_) {
      if (widget.autoOpenAddSheet && _isAdmin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAddMemberSheet();
        });
      }
    });
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
      title: AppLocalizations.of(context)!.promoteToAdmin,
      message:
          AppLocalizations.of(context)!.promoteQuestion(member['user_name']),
      confirmText: AppLocalizations.of(context)!.promote,
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
      _showSnackBar(AppLocalizations.of(context)!.nowAdmin(member['user_name']),
          isSuccess: true);
      _loadMembers();
    } else {
      _showSnackBar(AppLocalizations.of(context)!.errorPromoting, isSuccess: false);
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final confirmed = await _showConfirmDialog(
      title: AppLocalizations.of(context)!.expelMember,
      message:
          AppLocalizations.of(context)!.expelConfirmation(member['user_name']),
      confirmText: AppLocalizations.of(context)!.expel,
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
      _showSnackBar(AppLocalizations.of(context)!.userExpelled(member['user_name']),
          isSuccess: true);
      _loadMembers();
    } else {
      _showSnackBar(AppLocalizations.of(context)!.couldNotExpel, isSuccess: false);
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
      _showSnackBar(AppLocalizations.of(context)!.reportSentToAdmins, isSuccess: true);
    } else {
      _showSnackBar(AppLocalizations.of(context)!.errorSendingReport, isSuccess: false);
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
              AppLocalizations.of(context)!.cancel,
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
               AppLocalizations.of(context)!.reportDescription,
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
                hintText: AppLocalizations.of(context)!.reportReasonHint,
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
              AppLocalizations.of(context)!.cancel,
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
             child: Text(
              AppLocalizations.of(context)!.sendReport,
               style: const TextStyle(
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
                    title: AppLocalizations.of(context)!.makeAdmin,
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
                    subtitle: AppLocalizations.of(context)!.removeFromCommunity,
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
                  subtitle: AppLocalizations.of(context)!.sendReportToAdmins,
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

  // ─── Add Member Sheet ───

  void _showAddMemberSheet() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;
    String? statusMessage;
    bool hasSearched = false;
    Timer? debounce;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void performSearch(String query) {
            debounce?.cancel();
            if (query.trim().length < 2) {
              setSheetState(() {
                searchResults = [];
                hasSearched = false;
                statusMessage = null;
              });
              return;
            }
            debounce = Timer(const Duration(milliseconds: 500), () async {
              setSheetState(() {
                isSearching = true;
                statusMessage = null;
              });
              try {
                final results = await _communityService.searchUsers(
                  query,
                  excludeCommunityId: widget.communityId,
                );
                setSheetState(() {
                  searchResults = results;
                  isSearching = false;
                  hasSearched = true;
                });
              } catch (_) {
                setSheetState(() {
                  isSearching = false;
                  hasSearched = true;
                });
              }
            });
          }

          Future<void> addUser(Map<String, dynamic> user) async {
            setSheetState(() => statusMessage = 'Agregando ${user['name']}...');
            final result = await _communityService.addMemberDirectly(
              widget.communityId,
              user['uid'],
            );
            if (result.success && !result.alreadyMember) {
              setSheetState(() {
                statusMessage = null;
                searchResults.removeWhere((u) => u['uid'] == user['uid']);
              });
              _loadMembers();
              if (mounted) {
                _showSnackBar(result.message ?? '¡Miembro agregado!', isSuccess: true);
              }
            } else {
              setSheetState(() => statusMessage = null);
              if (mounted) {
                _showSnackBar(
                  result.message ?? AppLocalizations.of(context)!.couldNotAdd,
                  isSuccess: result.alreadyMember,
                );
              }
            }
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: Color(0xFF34C759),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Agregar Miembro',
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
                // Search field
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: performSearch,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.searchByEmailOrName,
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                        suffixIcon: isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF007AFF),
                                  ),
                                ),
                              )
                            : searchController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      searchController.clear();
                                      performSearch('');
                                    },
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                  )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                // Status message
                if (statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          statusMessage!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Results
                Flexible(
                  child: searchResults.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final user = searchResults[index];
                            final name = user['name'] as String;
                            final email = user['email'] as String;
                            final isFirst = index == 0;
                            final isLast = index == searchResults.length - 1;

                            return Container(
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
                                    onTap: statusMessage != null ? null : () => addUser(user),
                                    borderRadius: BorderRadius.vertical(
                                      top: isFirst ? const Radius.circular(12) : Radius.zero,
                                      bottom: isLast ? const Radius.circular(12) : Radius.zero,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          _buildAvatar(name, 'member'),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF1C1C1E),
                                                    letterSpacing: -0.2,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
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
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF34C759).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.add_rounded,
                                              color: Color(0xFF34C759),
                                              size: 20,
                                            ),
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
                          },
                        )
                      : hasSearched && searchResults.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.person_search_rounded,
                                      size: 28,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    AppLocalizations.of(context)!.noUsersFound,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppLocalizations.of(context)!.verifyAndRetry,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[400],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                AppLocalizations.of(context)!.minCharsToSearch,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      debounce?.cancel();
    });
  }

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
            Text(
              AppLocalizations.of(context)!.membersTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
            ),
            if (!_isLoading)
              Text(
                'AppLocalizations.of(context)!.memberCount(_members.length, _members.length == 1 ? AppLocalizations.of(context)!.memberSingular : AppLocalizations.of(context)!.memberPlural)',
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
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: _showAddMemberSheet,
              backgroundColor: const Color(0xFF1C1C1E),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person_add_rounded,
                color: Colors.white,
                size: 24,
              ),
            )
          : null,
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
           Text(
            AppLocalizations.of(context)!.noMembers,
             style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.noMembersFound,
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
