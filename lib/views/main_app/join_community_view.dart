import 'package:flutter/material.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/community_repository.dart';
import 'package:guardian/services/deep_link_service.dart';
import 'package:guardian/models/community_model.dart';
import 'package:guardian/views/main_app/community_feed_view.dart';

/// Pantalla para unirse a una comunidad mediante token de invitación
/// Se puede acceder por:
/// - Deep link (automático)
/// - Entrada manual de token/link
class JoinCommunityView extends StatefulWidget {
  final String? initialToken;

  const JoinCommunityView({
    super.key,
    this.initialToken,
  });

  @override
  State<JoinCommunityView> createState() => _JoinCommunityViewState();
}

class _JoinCommunityViewState extends State<JoinCommunityView> {
  final CommunityService _communityService = CommunityService();
  final CommunityRepository _communityRepository = CommunityRepository();
  final DeepLinkService _deepLinkService = DeepLinkService();
  final TextEditingController _tokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isValidating = false;
  String? _errorMessage;
  CommunityModel? _communityPreview;
  String? _currentToken;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) {
      _tokenController.text = widget.initialToken!;
      _validateToken(widget.initialToken!);
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  /// Valida el token y obtiene preview de la comunidad
  Future<void> _validateToken(String input) async {
    final token = _deepLinkService.parseTokenFromInput(input);
    if (token == null) {
      setState(() {
        _errorMessage = 'Token o link inválido';
        _communityPreview = null;
        _currentToken = null;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _communityPreview = null;
      _currentToken = token;
    });

    try {
      // Obtener información de la invitación
      final inviteInfo = await _communityService.getInviteInfo(token);
      
      if (inviteInfo == null) {
        setState(() {
          _errorMessage = 'Invitación no válida o expirada';
          _isValidating = false;
        });
        return;
      }

      final communityId = inviteInfo['community_id'] as String?;
      if (communityId == null) {
        setState(() {
          _errorMessage = 'Datos de invitación inválidos';
          _isValidating = false;
        });
        return;
      }

      // Obtener información de la comunidad
      final community = await _communityRepository.getCommunityById(communityId);
      
      setState(() {
        _communityPreview = community;
        _isValidating = false;
        if (community == null) {
          _errorMessage = 'Comunidad no encontrada';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error validando invitación';
        _isValidating = false;
      });
    }
  }

  /// Unirse a la comunidad
  Future<void> _joinCommunity() async {
    if (_currentToken == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _communityService.joinCommunityByToken(_currentToken!);
      
      if (result) {
        if (mounted) {
          // Mostrar éxito y navegar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _communityPreview != null
                    ? '¡Te has unido a ${_communityPreview!.name}!'
                    : '¡Te has unido a la comunidad!',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Navegar al feed de la comunidad si tenemos la info
          if (_communityPreview != null) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => CommunityFeedView(
                  communityId: _communityPreview!.id!,
                  communityName: _communityPreview!.name,
                  isEntity: _communityPreview!.isEntity,
                ),
              ),
            );
          } else {
            Navigator.of(context).pop(true);
          }
        }
      } else {
        setState(() {
          _errorMessage = 'No se pudo unir a la comunidad. El link puede haber expirado.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al unirse a la comunidad';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unirse a Comunidad'),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(
              Icons.group_add,
              size: 64,
              color: Color(0xFF1F2937),
            ),
            const SizedBox(height: 16),
            const Text(
              'Únete a una comunidad',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa el link o código de invitación que te compartieron',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Input de token
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: 'Link o código de invitación',
                  hintText: 'guardian.app/join/xxx o código',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _isValidating
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => _validateToken(_tokenController.text),
                        ),
                ),
                enabled: !_isLoading,
                onFieldSubmitted: _validateToken,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un link o código';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 8),
            
            // Botón validar (si no hay preview)
            if (_communityPreview == null && !_isValidating)
              TextButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _validateToken(_tokenController.text);
                  }
                },
                icon: const Icon(Icons.verified),
                label: const Text('Validar invitación'),
              ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Preview de la comunidad
            if (_communityPreview != null) ...[
              const SizedBox(height: 24),
              _buildCommunityPreview(),
              const SizedBox(height: 24),
              
              // Botón unirse
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _joinCommunity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2937),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _isLoading ? 'Uniéndose...' : 'Unirse a la comunidad',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],

            const SizedBox(height: 32),
            
            // Información adicional
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '¿Cómo funciona?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Los links de invitación expiran en 12 horas\n'
                    '• Puedes pegar el link completo o solo el código\n'
                    '• Una vez unido, recibirás las alertas de la comunidad',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.5,
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

  Widget _buildCommunityPreview() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Icono de la comunidad
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.people,
                color: Colors.green,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            
            // Nombre
            Text(
              _communityPreview!.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Descripción
            if (_communityPreview!.description != null &&
                _communityPreview!.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _communityPreview!.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Badge de invitación válida
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.green[700], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Invitación válida',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
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
}
