import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/alert_repository.dart';
import 'package:guardian/views/main_app/community_feed_view.dart';
import 'package:guardian/views/main_app/join_community_view.dart';

class ComunidadesView extends StatefulWidget {
  const ComunidadesView({super.key});

  @override
  State<ComunidadesView> createState() => _ComunidadesViewState();
}

class _ComunidadesViewState extends State<ComunidadesView> {
  final CommunityService _communityService = CommunityService();
  final AlertRepository _alertRepository = AlertRepository();
  List<Map<String, dynamic>> _communities = [];
  Map<String, int> _unreadByCommunity = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final communities = await _communityService.getMyCommunities();
      final unread = await _alertRepository.getUnreadCountByCommunity();
      if (!mounted) return;
      setState(() {
        _communities = communities;
        _unreadByCommunity = unread;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando comunidades: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar las comunidades. Intenta de nuevo.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: _loadCommunities,
            ),
          ),
        );
      }
    }
  }

  void _showCreateCommunityDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateCommunityDialog(
        onCommunityCreated: () {
          _loadCommunities();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.communities),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const JoinCommunityView(),
                ),
              ).then((joined) {
                if (joined == true) {
                  _loadCommunities();
                }
              });
            },
            tooltip: 'Unirse con link',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateCommunityDialog,
            tooltip: 'Crear comunidad',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando comunidades...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _communities.isEmpty
              ? _buildEmptyState()
              : _buildCommunitiesList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCommunityDialog,
        backgroundColor: const Color(0xFF1F2937),
        icon: const Icon(Icons.add),
        label: const Text('Crear Comunidad'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes comunidades',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las entidades aparecerán aquí automáticamente',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredCommunities {
    if (_searchQuery.trim().isEmpty) return _communities;
    final q = _searchQuery.trim().toLowerCase();
    return _communities.where((c) => (c['name'] as String? ?? '').toLowerCase().contains(q)).toList();
  }

  Widget _buildCommunitiesList() {
    return Column(
      children: [
        if (_communities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Buscar comunidades...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCommunities,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredCommunities.length,
              itemBuilder: (context, index) {
                final community = _filteredCommunities[index];
                return _buildCommunityCard(community);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityCard(Map<String, dynamic> community) {
    final isEntity = community['is_entity'] as bool;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isEntity 
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isEntity ? Icons.shield : Icons.people,
            color: isEntity ? Colors.blue : Colors.green,
            size: 24,
          ),
        ),
        title: Text(
          community['name'] ?? '',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (community['description'] != null) ...[
              const SizedBox(height: 4),
              Text(
                community['description'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            if (isEntity)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Entidad Oficial',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((community['id'] != null) && ((_unreadByCommunity[community['id'] as String] ?? 0) > 0))
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_unreadByCommunity[community['id'] as String]}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          final communityId = community['id'] as String;
          final communityName = community['name'] as String;
          final isEntity = community['is_entity'] as bool;
          
          // Solo navegar al feed si NO es entidad
          if (!isEntity) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommunityFeedView(
                  communityId: communityId,
                  communityName: communityName,
                  isEntity: false,
                ),
              ),
            );
          } else {
            // Para entidades, mostrar mensaje (por ahora)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${community['name']} es una entidad oficial'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }
}

// Diálogo para crear nueva comunidad
class _CreateCommunityDialog extends StatefulWidget {
  final VoidCallback onCommunityCreated;

  const _CreateCommunityDialog({required this.onCommunityCreated});

  @override
  State<_CreateCommunityDialog> createState() => _CreateCommunityDialogState();
}

class _CreateCommunityDialogState extends State<_CreateCommunityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final CommunityService _communityService = CommunityService();
  bool _allowForwardToEntities = true;
  bool _isCreating = false;

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
        allowForwardToEntities: _allowForwardToEntities,
      );

      if (communityId != null && mounted) {
        Navigator.pop(context);
        widget.onCommunityCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Comunidad creada exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error creando la comunidad'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Nueva Comunidad'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la comunidad *',
                  hintText: 'Ej: Vecinos del Barrio',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (value.trim().length < 3) {
                    return 'El nombre debe tener al menos 3 caracteres';
                  }
                  return null;
                },
                enabled: !_isCreating,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Describe el propósito de la comunidad',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !_isCreating,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Permitir reenvío a entidades'),
                subtitle: const Text(
                  'Los miembros podrán reenviar alertas a entidades oficiales',
                ),
                value: _allowForwardToEntities,
                onChanged: _isCreating
                    ? null
                    : (value) {
                        setState(() {
                          _allowForwardToEntities = value;
                        });
                      },
                activeColor: const Color(0xFF1F2937),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createCommunity,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F2937),
            foregroundColor: Colors.white,
          ),
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }
}
