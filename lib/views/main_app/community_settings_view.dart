import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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

  void _showEditCommunityDialog() {
    final nameController = TextEditingController(text: _community?.name ?? '');
    final descriptionController = TextEditingController(text: _community?.description ?? '');
    final formKey = GlobalKey<FormState>();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Comunidad'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la comunidad *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El nombre es requerido';
                      }
                      if (value.trim().length < 3) {
                        return 'Mínimo 3 caracteres';
                      }
                      return null;
                    },
                    enabled: !isUpdating,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                    enabled: !isUpdating,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isUpdating
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isUpdating = true);

                      final newName = nameController.text.trim();
                      final newDescription = descriptionController.text.trim();

                      final success = await _communityService.updateCommunity(
                        widget.communityId,
                        name: newName,
                        description: newDescription.isEmpty ? null : newDescription,
                      );

                      if (mounted) {
                        Navigator.pop(context);

                        if (success) {
                          setState(() {
                            _community = _community!.copyWith(
                              name: newName,
                              description: newDescription.isEmpty ? null : newDescription,
                            );
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Comunidad actualizada'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error actualizando la comunidad'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2937),
                foregroundColor: Colors.white,
              ),
              child: isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
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
    final communityName = _community?.name ?? 'la comunidad';
    
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
                'https://$link',
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
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'https://$link'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copiado al portapapeles'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Share.share(
                '¡Únete a $communityName en Guardian!\n\nhttps://$link',
                subject: 'Invitación a $communityName - Guardian',
              );
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Compartir'),
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
      final success = await _communityService.updateCommunity(
        widget.communityId,
        allowForwardToEntities: value,
      );
      
      if (success) {
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solo el creador puede modificar la configuración'),
              backgroundColor: Colors.orange,
            ),
          );
        }
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

  Future<void> _deleteCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[400]),
            const SizedBox(width: 8),
            const Text('Eliminar Comunidad'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que quieres eliminar esta comunidad?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Esta acción es irreversible y eliminará:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text('• Todos los miembros', style: TextStyle(fontSize: 14)),
            Text('• Todas las invitaciones', style: TextStyle(fontSize: 14)),
            Text('• La comunidad por completo', style: TextStyle(fontSize: 14)),
            SizedBox(height: 12),
            Text(
              'Las alertas enviadas a esta comunidad permanecerán en el historial.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final success = await _communityService.deleteCommunity(widget.communityId);
      
      if (mounted) {
        Navigator.pop(context); // Cerrar indicador de carga
        
        if (success) {
          Navigator.pop(context); // Volver de settings
          Navigator.pop(context); // Volver de feed a lista de comunidades
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comunidad eliminada'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al eliminar la comunidad'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _community!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isAdmin)
                        IconButton(
                          onPressed: _showEditCommunityDialog,
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Editar comunidad',
                          style: IconButton.styleFrom(
                            foregroundColor: const Color(0xFF1F2937),
                          ),
                        ),
                    ],
                  ),
                  if (_community!.description != null && _community!.description!.isNotEmpty) ...[
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
          
          // Opciones de invitación (todos los miembros)
          const Text(
            'Invitar Miembros',
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
              leading: const Icon(Icons.person_add, color: Color(0xFF1F2937)),
              title: const Text('Generar link de invitación'),
              subtitle: _isGeneratingLink
                  ? const Text('Generando...')
                  : const Text('Comparte el link para invitar a otros'),
              trailing: _isGeneratingLink
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _isGeneratingLink ? null : _generateInviteLink,
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
              child: SwitchListTile(
                title: const Text('Permitir reenvío a entidades'),
                subtitle: const Text(
                  'Permite que los miembros reenvíen alertas a entidades oficiales',
                ),
                value: _community!.allowForwardToEntities,
                onChanged: _updateAllowForward,
                activeColor: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            // Zona de peligro - Eliminar comunidad
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red[400]),
                title: Text(
                  'Eliminar comunidad',
                  style: TextStyle(color: Colors.red[700]),
                ),
                subtitle: const Text(
                  'Elimina la comunidad permanentemente',
                ),
                onTap: _deleteCommunity,
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
