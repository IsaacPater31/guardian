import 'package:flutter/material.dart';
import 'package:guardian/services/quick_alert_config_service.dart';

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
          _buildSectionHeader('Alertas'),
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
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Sección: General (placeholder para futuras configuraciones)
          _buildSectionHeader('General'),
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
                  title: const Text('Acerca de'),
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
                        'Por defecto: todas las entidades',
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
