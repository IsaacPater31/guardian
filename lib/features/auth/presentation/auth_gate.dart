import 'package:flutter/material.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/auth/application/login_handler.dart';
import 'package:guardian/features/auth/application/user_service.dart';
import 'package:guardian/features/auth/presentation/login_view.dart';
import 'package:guardian/features/home_shell/presentation/main_view.dart';
import 'package:guardian/features/communities/presentation/join_community_view.dart';
import 'package:guardian/features/home_shell/application/deep_link_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _hasCheckedPendingToken = false;
  final LoginHandler _loginHandler = LoginHandler();
  final UserService _userService = UserService();
  /// Evita sync duplicado en reconstrucciones del [StreamBuilder].
  String? _lastProfileSyncUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _userService.authUidChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final uid = snapshot.data;
        if (uid != null) {
          if (_lastProfileSyncUid != uid) {
            _lastProfileSyncUid = uid;
            _loginHandler.syncCurrentUserProfileAfterAuth().catchError((error) {
              AppLogger.w(
                'AuthGate: syncCurrentUserProfileAfterAuth failed: $error',
              );
            });
          }

          if (!_hasCheckedPendingToken) {
            _hasCheckedPendingToken = true;
            _checkPendingInviteToken();
          }

          return const MainView();
        }
        _hasCheckedPendingToken = false;
        _lastProfileSyncUid = null;
        return const LoginView();
      },
    );
  }

  Future<void> _checkPendingInviteToken() async {
    try {
      final deepLinkService = DeepLinkService();
      final pendingToken = await deepLinkService.consumePendingToken();

      if (pendingToken != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  JoinCommunityView(initialToken: pendingToken),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.w('AuthGate: pending invite token check failed: $e');
    }
  }
}
