import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/features/auth/application/login_handler.dart';
import 'package:guardian/features/auth/application/user_service.dart';

class PerfilView extends StatefulWidget {
  const PerfilView({super.key});

  @override
  State<PerfilView> createState() => _PerfilViewState();
}

class _PerfilViewState extends State<PerfilView> {
  final UserService _userService = UserService();
  final LoginHandler _loginHandler = LoginHandler();

  String? _displayName;
  String? _email;

  @override
  void initState() {
    super.initState();
    _pullSessionFields();
  }

  void _pullSessionFields() {
    setState(() {
      _displayName = _userService.currentUserName?.trim();
      _email = _userService.currentUserEmail?.trim();
    });
  }

  Future<void> _onRefresh() async {
    try {
      await _userService.reloadCurrentUser();
    } catch (_) {
      // Keep last known user if reload fails (offline, etc.).
    }
    if (!mounted) return;
    _pullSessionFields();
  }

  Future<void> _signOut() async {
    await _loginHandler.signOut();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.logout)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = (_displayName != null && _displayName!.isNotEmpty)
        ? _displayName!
        : (_email != null && _email!.isNotEmpty)
            ? _email!
            : l10n.profileInfo;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: Text(
          l10n.profile,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF007AFF),
          onRefresh: _onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 40),
              const Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Color(0xFF1F2937),
                  child: Icon(Icons.person, size: 56, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.35),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: Text(
                    l10n.logout,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
