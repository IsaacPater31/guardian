import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/community_repository.dart';
import 'package:guardian/models/community_model.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  Future<void> _loadCommunity() async {
    setState(() => _isLoading = true);
    try {
      final community = await _communityRepository.getCommunityById(widget.communityId);
      setState(() {
        _community = community;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando comunidad: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateInviteLink() async {
    setState(() => _isGeneratingLink = true);
    try {
      final link = await _communityService.generateInviteLink(widget.communityId);
      if (link != null) {
        setState(() => _isGeneratingLink = false);
        // Mostrar diálogo con el link
        _showInviteLinkDialog(link);
      } else {
        setState(() => _isGeneratingLink = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error generando link de invitación'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isGeneratingLink = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInviteLinkDialog(String link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link de Invitación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparte este link para invitar a otros a la comunidad:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ El link expira en 12 horas',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copiado al portapapeles'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAllowForward(bool value) async {
    if (_community == null) return;

    try {
      await _communityRepository.updateCommunity(
        widget.communityId,
        {'allow_forward_to_entities': value},
      );
      setState(() {
        _community = _community!.copyWith(allowForwardToEntities: value);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Reenvío a entidades habilitado'
                  : 'Reenvío a entidades deshabilitado',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error actualizando configuración: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonar Comunidad'),
        content: const Text(
          '¿Estás seguro de que quieres abandonar esta comunidad? No podrás ver sus alertas ni participar en ella.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _communityService.leaveCommunity(widget.communityId);
      if (mounted) {
        if (success) {
          Navigator.pop(context); // Volver a la lista de comunidades
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Has abandonado la comunidad'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          // Verificar si es porque es admin
          final role = await _communityService.getUserRole(widget.communityId);
          final errorMessage = role == 'admin'
              ? 'El administrador no puede abandonar su propia comunidad'
              : 'Error al abandonar la comunidad';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Configuración'),
          backgroundColor: const Color(0xFF1F2937),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_community == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Configuración'),
          backgroundColor: const Color(0xFF1F2937),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Error cargando comunidad'),
        ),
      );
    }

    final isAdmin = widget.userRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Información de la comunidad
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _community!.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_community!.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _community!.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Opciones de administrador
          if (isAdmin) ...[
            const Text(
              'Opciones de Administrador',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Permitir reenvío a entidades'),
                    subtitle: const Text(
                      'Permite que los miembros reenvíen alertas a entidades oficiales',
                    ),
                    value: _community!.allowForwardToEntities,
                    onChanged: _updateAllowForward,
                    activeColor: const Color(0xFF1F2937),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Generar link de invitación'),
                    subtitle: _isGeneratingLink
                        ? const Text('Generando...')
                        : const Text('Crea un link para invitar a otros'),
                    trailing: _isGeneratingLink
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isGeneratingLink ? null : _generateInviteLink,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          // Opciones de miembro
          const Text(
            'Opciones de Miembro',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.red[400]),
              title: const Text('Abandonar comunidad'),
              subtitle: const Text(
                'Dejarás de recibir alertas de esta comunidad',
              ),
              onTap: _leaveCommunity,
            ),
          ),
        ],
      ),
    );
  }
}
