import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/services/quick_alert_config_service.dart';
import 'package:guardian/services/swipe_alert_config_service.dart';
import 'package:guardian/models/emergency_types.dart';

/// Pantalla de configuración principal
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
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
          // Sección: Alertas
          _buildSectionHeader(AppLocalizations.of(context)!.alertsSection),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.flash_on, color: Color(0xFF1F2937)),
                  title: const Text('Alertas Rápidas'),
                  subtitle: const Text('Configurar destinos de alertas rápidas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QuickAlertConfigView(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.swipe, color: Color(0xFF1F2937)),
                  title: const Text('Alertas por Tipo'),
                  subtitle: const Text('Configurar comunidades por tipo de alerta'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SwipeAlertConfigView(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Sección: General (placeholder para futuras configuraciones)
          _buildSectionHeader(AppLocalizations.of(context)!.generalSection),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Color(0xFF1F2937)),
                  title: Text(AppLocalizations.of(context)!.about),
                  subtitle: const Text('Información de la aplicación'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Implementar pantalla de "Acerca de"
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Próximamente'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
      ),
    );
  }
}

/// Vista de configuración de quick alerts
class QuickAlertConfigView extends StatefulWidget {
  const QuickAlertConfigView({super.key});

  @override
  State<QuickAlertConfigView> createState() => _QuickAlertConfigViewState();
}

// ─────────────────────────────────────────────────────────────────────────────
// QuickAlertConfigViewState  (sin cambios relevantes)
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAlertConfigViewState extends State<QuickAlertConfigView> {
  final QuickAlertConfigService _configService = QuickAlertConfigService();
  List<Map<String, dynamic>> _availableDestinations = [];
  Set<String> _selectedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    setState(() => _isLoading = true);
    
    try {
      // Obtener comunidades disponibles
      final destinations = await _configService.getAvailableDestinations();
      
      // Obtener configuración actual
      final currentConfig = await _configService.getQuickAlertDestinations();
      
      setState(() {
        _availableDestinations = destinations;
        _selectedIds = currentConfig.toSet();
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando configuración: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveConfiguration() async {
    final success = await _configService.updateQuickAlertDestinations(_selectedIds.toList());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Configuración guardada'
                : '❌ Error guardando configuración',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas Rápidas'),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header informativo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Configuración de Alertas Rápidas',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Selecciona a qué comunidades se enviarán las alertas rápidas cuando presiones el botón de emergencia.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.defaultAllEntities,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Lista de comunidades
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableDestinations.length,
                    itemBuilder: (context, index) {
                      final destination = _availableDestinations[index];
                      final id = destination['id'] as String;
                      final name = destination['name'] as String;
                      final isEntity = destination['is_entity'] as bool;
                      final isSelected = _selectedIds.contains(id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: isEntity
                              ? Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Entidad Oficial',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : null,
                          secondary: Container(
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
                        ),
                      );
                    },
                  ),
                ),
                
                // Botón guardar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () async {
                                await _saveConfiguration();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F2937),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Guardar Configuración',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// =============================================================================
// SwipeAlertConfigView — Configuración de comunidades por tipo de alerta
// =============================================================================

class SwipeAlertConfigView extends StatefulWidget {
  final String? initialAlertType;
  const SwipeAlertConfigView({super.key, this.initialAlertType});

  @override
  State<SwipeAlertConfigView> createState() => _SwipeAlertConfigViewState();
}

class _SwipeAlertConfigViewState extends State<SwipeAlertConfigView> {
  final SwipeAlertConfigService _configService = SwipeAlertConfigService();
  List<Map<String, dynamic>> _communities = [];
  final Map<String, Set<String>> _selectedByType = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final communities = await _configService.getAvailableCommunities();
      final Map<String, Set<String>> byType = {};
      for (final alertType in EmergencyTypes.allTypes) {
        final saved = await _configService.getCommunitiesForType(alertType);
        byType[alertType] = saved != null ? saved.toSet() : {};
      }
      if (mounted) {
        setState(() {
          _communities = communities;
          _selectedByType.addAll(byType);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    int saved = 0;
    for (final entry in _selectedByType.entries) {
      final ok = await _configService.setCommunitiesForType(
          entry.key, entry.value.toList());
      if (ok) saved++;
    }
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved == _selectedByType.length
              ? '✅ Configuración guardada'
              : '⚠️ Algunos tipos no se guardaron'),
          backgroundColor:
              saved == _selectedByType.length ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas por Tipo'),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[700], size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Define a qué comunidades se enviará cada tipo de alerta al arrastrar el botón. Si no configuras un tipo, se te pedirá al momento de enviar.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: EmergencyTypes.types.length,
                    itemBuilder: (context, index) {
                      final entry =
                          EmergencyTypes.types.entries.toList()[index];
                      final typeData = entry.value;
                      final typeName = typeData['type'] as String;
                      final color = typeData['color'] as Color;
                      final icon = typeData['icon'] as IconData;
                      final label =
                          EmergencyTypes.getTranslatedType(typeName, context);
                      final selected = _selectedByType[typeName] ?? {};
                      final isHighlighted =
                          widget.initialAlertType == typeName;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: isHighlighted ? 4 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: isHighlighted
                              ? BorderSide(
                                  color: color.withValues(alpha: 0.7),
                                  width: 2)
                              : BorderSide.none,
                        ),
                        child: Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: color, size: 22),
                            ),
                            title: Text(label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            subtitle: selected.isEmpty
                                ? Text(
                                    'Sin comunidad por defecto — se pedirá al enviar',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange[700]),
                                  )
                                : Text(
                                    '${selected.length} comunidad${selected.length != 1 ? 'es' : ''} configurada${selected.length != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.green),
                                  ),
                            initiallyExpanded: isHighlighted,
                            children: _communities.isEmpty
                                ? [
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                          'No tienes comunidades disponibles',
                                          style:
                                              TextStyle(color: Colors.grey)),
                                    )
                                  ]
                                : _communities.map((community) {
                                    final id = community['id'] as String;
                                    final isEntity =
                                        community['is_entity'] as bool;
                                    final isSelected = selected.contains(id);
                                    return CheckboxListTile(
                                      value: isSelected,
                                      onChanged: (val) {
                                        setState(() {
                                          final set = Set<String>.from(
                                              _selectedByType[typeName] ?? {});
                                          val == true
                                              ? set.add(id)
                                              : set.remove(id);
                                          _selectedByType[typeName] = set;
                                        });
                                      },
                                      activeColor: color,
                                      title: Text(
                                          community['name'] as String? ?? '',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500)),
                                      secondary: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isEntity
                                              ? Colors.blue
                                                  .withValues(alpha: 0.1)
                                              : Colors.green
                                                  .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isEntity
                                              ? Icons.shield
                                              : Icons.people,
                                          color: isEntity
                                              ? Colors.blue
                                              : Colors.green,
                                          size: 18,
                                        ),
                                      ),
                                      subtitle: isEntity
                                          ? const Text('Entidad Oficial',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blue))
                                          : null,
                                    );
                                  }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F2937),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Guardar Configuración',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
