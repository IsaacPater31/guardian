import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar deep links de invitaciones
/// Soporta:
/// - https://guardian.app/join/{token}
/// - guardian://join/{token}
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription<Uri>? _linkSubscription;
  
  // Callback para cuando se recibe un token de invitación
  Function(String token)? onInviteTokenReceived;
  
  // Token pendiente (para cuando el usuario no está autenticado)
  static const String _pendingTokenKey = 'pending_invite_token';

  /// Inicializa el servicio de deep links
  /// Debe llamarse en main.dart después de Firebase.initializeApp()
  Future<void> initialize() async {
    // Verificar si hay un link inicial (app abierta desde link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print('❌ Error obteniendo link inicial: $e');
    }

    // Escuchar links mientras la app está abierta
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (error) {
        print('❌ Error en stream de deep links: $error');
      },
    );
  }

  /// Procesa un deep link
  void _handleDeepLink(Uri uri) {
    print('🔗 Deep link recibido: $uri');
    
    final token = _extractToken(uri);
    if (token != null) {
      print('🎟️ Token de invitación extraído: $token');
      _processInviteToken(token);
    }
  }

  /// Extrae el token de un URI
  /// Soporta:
  /// - https://guardian.app/join/{token}
  /// - guardian://join/{token}
  String? _extractToken(Uri uri) {
    // Formato: guardian.app/join/{token}
    if (uri.host == 'guardian.app' && uri.pathSegments.isNotEmpty) {
      if (uri.pathSegments.first == 'join' && uri.pathSegments.length >= 2) {
        return uri.pathSegments[1];
      }
    }
    
    // Formato: guardian://join/{token}
    if (uri.scheme == 'guardian' && uri.host == 'join') {
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      // Si el token está como path sin segmentos adicionales
      final path = uri.path;
      if (path.startsWith('/')) {
        return path.substring(1);
      }
      return path.isNotEmpty ? path : null;
    }
    
    return null;
  }

  /// Procesa un token de invitación
  Future<void> _processInviteToken(String token) async {
    final user = _auth.currentUser;
    
    if (user != null) {
      // Usuario autenticado - notificar inmediatamente
      onInviteTokenReceived?.call(token);
    } else {
      // Usuario no autenticado - guardar token pendiente
      await savePendingToken(token);
      print('💾 Token guardado como pendiente (usuario no autenticado)');
    }
  }

  /// Guarda un token pendiente para procesar después del login
  Future<void> savePendingToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingTokenKey, token);
  }

  /// Obtiene y elimina el token pendiente
  Future<String?> consumePendingToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_pendingTokenKey);
    if (token != null) {
      await prefs.remove(_pendingTokenKey);
      print('🎟️ Token pendiente consumido: $token');
    }
    return token;
  }

  /// Verifica si hay un token pendiente
  Future<bool> hasPendingToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pendingTokenKey);
  }

  /// Parsea un token desde un link completo o token directo
  /// Útil para entrada manual
  String? parseTokenFromInput(String input) {
    input = input.trim();
    
    // Si es solo el token (32 caracteres alfanuméricos)
    if (RegExp(r'^[a-zA-Z0-9]{32}$').hasMatch(input)) {
      return input;
    }
    
    // Intentar parsear como URI
    try {
      final uri = Uri.parse(input);
      return _extractToken(uri);
    } catch (e) {
      return null;
    }
  }

  /// Libera recursos
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}

/// Widget que envuelve la app para manejar deep links
class DeepLinkHandler extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const DeepLinkHandler({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    _setupDeepLinkListener();
  }

  void _setupDeepLinkListener() {
    _deepLinkService.onInviteTokenReceived = (token) {
      // Navegar a la pantalla de unirse a comunidad
      _navigateToJoinCommunity(token);
    };
  }

  void _navigateToJoinCommunity(String token) {
    final navigator = widget.navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushNamed('/join-community', arguments: token);
    }
  }

  @override
  void dispose() {
    _deepLinkService.onInviteTokenReceived = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
