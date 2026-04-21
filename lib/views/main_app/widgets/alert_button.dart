import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardian/core/alert_detail_catalog.dart';
import 'package:guardian/controllers/alert_controller.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/swipe_alert_config_service.dart';
import 'package:guardian/services/quick_alert_config_service.dart';
import 'package:guardian/views/main_app/settings_view.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

class AlertButton extends StatefulWidget {
  final VoidCallback onPressed;

  const AlertButton({super.key, required this.onPressed});

  @override
  State<AlertButton> createState() => _AlertButtonState();
}

class _AlertButtonState extends State<AlertButton> with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF007AFF);
  static const Color _primaryDark = Color(0xFF1C1C1E);
  static const Color _danger = Color(0xFFFF3B30);
  static const Color _surface = Color(0xFFF8F9FA);

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  bool _showEmergencyOptions = false;
  String _currentEmergencyType = '';
  bool _isGestureActive = false;
  
  Offset _dragOffset = Offset.zero;
  
  String? _currentDragDirection;
  bool _showDragFeedback = false;
  
  final AlertController _alertController = AlertController();
  final CommunityService _communityService = CommunityService();
  final SwipeAlertConfigService _swipeConfig = SwipeAlertConfigService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    // Pre-configurar comunidades por defecto basado en keywords
    // (p.ej. POLICE → POLICIA, FIRE → BOMBEROS, etc.)
    _initDefaultCommunities();
  }

  /// Carga las comunidades del usuario e inicializa la configuración por defecto
  /// de cada tipo de alerta si aún no está configurada.
  Future<void> _initDefaultCommunities() async {
    try {
      final communities = await _swipeConfig.getAvailableCommunities();
      if (communities.isNotEmpty) {
        await _swipeConfig.initDefaults(communities);
      }
    } catch (e) {
      // No bloquear la UI si falla la inicialización
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleGesture(String direction) {
    if (EmergencyTypes.types.containsKey(direction) && !_isGestureActive) {
      _isGestureActive = true;
      HapticFeedback.mediumImpact();
      setState(() {
        _currentEmergencyType = direction;
        _showEmergencyOptions = true;
      });
      _animationController.forward();
      
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _showEmergencyDialog(EmergencyTypes.types[direction]!['type']);
        }
      });
    }
  }

  void _sendQuickAlert() async {
    HapticFeedback.heavyImpact();

    // Obtener los destinos configurados para alertas rápidas
    final quickConfig = QuickAlertConfigService();
    final destinations = await quickConfig.getQuickAlertDestinations();

    if (!mounted) return;

    if (destinations.isEmpty) {
      // Sin configuración — redirigir a ajustes
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.settings, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No hay comunidades configuradas. Configura las alertas rápidas en Ajustes.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Configurar',
            textColor: const Color(0xFF007AFF),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const QuickAlertConfigView(),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text(AppLocalizations.of(context)!.sendingAlert),
          ],
        ),
        backgroundColor: _primaryDark,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    // AlertController.sendQuickAlert fetches destinations from QuickAlertConfigService
    // internally and sends to all of them in a single batch — just call it once.
    final ok = await _alertController.sendQuickAlert(
      alertType: EmergencyTypes.quickAlertType,
      isAnonymous: false,
    );
    final int successCount = ok ? destinations.length : 0;

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    if (!mounted) return;
    if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: _primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.alertSent,
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16,
                        ),
                      ),
                      Text(
                        'Enviada a $successCount comunidad${successCount > 1 ? 'es' : ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: _primaryDark,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSendingAlert),
          backgroundColor: _danger,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showEmergencyDialog(String emergencyType) async {
    final emergencyData = EmergencyTypes.getTypeByName(emergencyType);
    if (emergencyData == null || emergencyData.isEmpty) return;

    // 1. Verificar si hay comunidades configuradas por defecto para este tipo
    final configuredIds = await _swipeConfig.getCommunitiesForType(emergencyType);

    if (configuredIds != null && configuredIds.isNotEmpty) {
      // Hay configuración guardada — obtener los datos de esas comunidades
      final allCommunities = await _swipeConfig.getAvailableCommunities();
      final preselected = allCommunities
          .where((c) => configuredIds.contains(c['id'] as String))
          .toList();

      if (preselected.isNotEmpty && mounted) {
        // Mostrar diag de confirmación con las comunidades pre-seleccionadas
        final selected =
            await _showCommunitySelectionDialog(emergencyType, preSelectedIds: configuredIds.toSet());
        if (selected != null && selected.isNotEmpty && mounted) {
          _showFinalConfirmationDialog(emergencyType, selected);
        } else {
          _hideEmergencyOptions();
        }
        return;
      }
    }

    // 2. No hay config guardada — buscar por keyword por defecto
    final keyword = EmergencyTypes.getDefaultCommunityKeyword(emergencyType);
    if (keyword != null) {
      final allCommunities = await _swipeConfig.getAvailableCommunities();
      final initialIds = allCommunities
          .where((c) {
            final name = (c['name'] as String? ?? '').toUpperCase();
            return name.contains(keyword);
          })
          .map((c) => c['id'] as String)
          .toSet();

      if (!mounted) return;
      final selected = await _showCommunitySelectionDialog(
          emergencyType, preSelectedIds: initialIds);
      if (selected != null && selected.isNotEmpty && mounted) {
        _showFinalConfirmationDialog(emergencyType, selected);
      } else {
        _hideEmergencyOptions();
      }
      return;
    }

    // 3. Sin keyword y sin config — mostrar aviso y abrir configuración
    if (mounted) {
      _hideEmergencyOptions();
      final typeName = EmergencyTypes.getTranslatedType(emergencyType, context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.settings, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Configura las comunidades para "$typeName" en Ajustes.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Configurar',
            textColor: const Color(0xFF007AFF),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SwipeAlertConfigView(
                    initialAlertType: emergencyType,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>?> _showCommunitySelectionDialog(
      String emergencyType, {Set<String> preSelectedIds = const {}}) async {
    if (!mounted) return null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final communities = await _communityService.getMyCommunities();

      if (mounted) Navigator.of(context).pop();

      if (communities.isEmpty) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes comunidades disponibles'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return null;
      }

      if (!mounted) return null;

      // Pre-seleccionar según configuración o keyword
      final Set<String> selectedCommunityIds = Set<String>.from(preSelectedIds);

      final selectedCommunities = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            final sw = MediaQuery.of(context).size.width;
            final sh = MediaQuery.of(context).size.height;
            final isSmall = sw < 360;
            final dialogPadding = isSmall ? 14.0 : 20.0;
            final titleFontSize = isSmall ? 16.0 : 20.0;
            final subtitleFontSize = isSmall ? 12.0 : 14.0;

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: isSmall ? 10 : 18,
                vertical: isSmall ? 12 : 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: SafeArea(
                child: Container(
                constraints: BoxConstraints(
                  maxWidth: (sw * 0.95).clamp(0.0, 420.0),
                  maxHeight: sh * (isSmall ? 0.85 : 0.80),
                ),
                padding: EdgeInsets.all(dialogPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmall ? 6 : 8),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.people,
                            color: _primary,
                            size: isSmall ? 20 : 24,
                          ),
                        ),
                        SizedBox(width: isSmall ? 8 : 12),
                        Expanded(
                          child: Text(
                            'Seleccionar Comunidades',
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: isSmall ? 20 : 24),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: isSmall ? 32 : 40,
                            minHeight: isSmall ? 32 : 40,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmall ? 8 : 12),
                    Text(
                      'Selecciona una o más comunidades',
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (selectedCommunityIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${selectedCommunityIds.length} seleccionada${selectedCommunityIds.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _primary,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: isSmall ? 10 : 14),
                    Expanded(
                      child: ListView.builder(
                        itemCount: communities.length,
                        itemBuilder: (context, index) {
                          final community = communities[index];
                          final isEntity = community['is_entity'] as bool;
                          final communityId = community['id'] as String;
                          final isSelected = selectedCommunityIds.contains(communityId);

                          return Card(
                            margin: EdgeInsets.only(bottom: isSmall ? 6 : 8),
                            color: isSelected
                                ? _primary.withValues(alpha: 0.10)
                                : Colors.white,
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isSmall ? 10 : 16,
                                vertical: isSmall ? 2 : 4,
                              ),
                              leading: Container(
                                width: isSmall ? 34 : 40,
                                height: isSmall ? 34 : 40,
                                decoration: BoxDecoration(
                                  color: isEntity
                                      ? _primary.withValues(alpha: 0.10)
                                      : const Color(0xFF5AC8FA).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isEntity ? Icons.shield : Icons.people,
                                  color: isEntity ? _primary : const Color(0xFF5AC8FA),
                                  size: isSmall ? 17 : 20,
                                ),
                              ),
                              title: Text(
                                community['name'] ?? '',
                                style: TextStyle(
                                  fontSize: isSmall ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? _primary : _primaryDark,
                                ),
                              ),
                              subtitle: community['description'] != null
                                  ? Text(
                                      community['description'] ?? '',
                                      style: TextStyle(
                                        fontSize: isSmall ? 11 : 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedCommunityIds.add(communityId);
                                    } else {
                                      selectedCommunityIds.remove(communityId);
                                    }
                                  });
                                },
                                activeColor: _primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    selectedCommunityIds.remove(communityId);
                                  } else {
                                    selectedCommunityIds.add(communityId);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: isSmall ? 10 : 14),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: isSmall ? 44 : 48,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: isSmall ? 13 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isSmall ? 8 : 12),
                        Expanded(
                          child: SizedBox(
                            height: isSmall ? 44 : 48,
                            child: ElevatedButton.icon(
                              onPressed: selectedCommunityIds.isNotEmpty
                                  ? () {
                                      final selected = communities
                                          .where((c) => selectedCommunityIds
                                              .contains(c['id']))
                                          .toList();
                                      Navigator.of(context).pop(selected);
                                    }
                                  : null,
                              icon: Icon(Icons.arrow_forward,
                                  size: isSmall ? 16 : 18),
                              label: Text(
                                'Continuar',
                                style: TextStyle(
                                  fontSize: isSmall ? 13 : 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedCommunityIds.isNotEmpty
                                    ? _primaryDark
                                    : Colors.grey,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        ),
      );

      return selectedCommunities;
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando comunidades: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return null;
    }
  }

  void _showFinalConfirmationDialog(String emergencyType, List<Map<String, dynamic>> selectedCommunities) {
    final emergencyData = EmergencyTypes.getTypeByName(emergencyType);
    if (emergencyData == null) return;
    final translatedType = EmergencyTypes.getTranslatedType(emergencyType, context);
    final subtypeOptions = AlertDetailCatalog.getSubtypes(emergencyType);
    String? selectedSubtype = subtypeOptions.isNotEmpty ? subtypeOptions.first.id : null;
    bool isAnonymous = false;
    final TextEditingController otherController = TextEditingController();
    final List<String> photoPlaceholders = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final requiresOtherDetail =
              selectedSubtype != null && AlertDetailCatalog.subtypeRequiresDetail(emergencyType, selectedSubtype!);

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            otherController.dispose();
                            _showCommunitySelectionDialog(emergencyType).then((selection) {
                              if (selection != null && selection.isNotEmpty && mounted) {
                                _showFinalConfirmationDialog(emergencyType, selection);
                              } else {
                                _hideEmergencyOptions();
                              }
                            });
                          },
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Expanded(
                          child: Text(
                            'Detalle de alerta',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: _danger.withValues(alpha: 0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(emergencyData['icon'], color: _danger, size: 34),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  translatedType,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _primary.withValues(alpha: 0.18)),
                            ),
                            child: Text(
                              'Comunidades seleccionadas: ${selectedCommunities.map((c) => c['name']).join(', ')}',
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Subtipo o motivo', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedSubtype,
                            items: subtypeOptions
                                .map((option) => DropdownMenuItem<String>(
                                      value: option.id,
                                      child: Text(option.label),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedSubtype = value;
                              });
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                          if (requiresOtherDetail) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: otherController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'Describe el caso',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text('Enviar como anónima'),
                            subtitle: const Text('Tu nombre no se mostrará en la alerta'),
                            value: isAnonymous,
                            onChanged: (value) => setDialogState(() => isAnonymous = value),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _primary.withValues(alpha: 0.35)),
                              color: _primary.withValues(alpha: 0.08),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fotos (boceto visual)',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: _primary),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'La carga real al servidor se habilitará en una siguiente fase.',
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...photoPlaceholders.map((p) => Chip(
                                          avatar: const Icon(Icons.image, size: 16),
                                          label: Text(p, style: const TextStyle(fontSize: 12)),
                                        )),
                                    ActionChip(
                                      avatar: const Icon(Icons.add_a_photo, size: 16),
                                      label: const Text('Agregar placeholder'),
                                      onPressed: () {
                                        setDialogState(() {
                                          photoPlaceholders.add('Foto ${photoPlaceholders.length + 1}');
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              otherController.dispose();
                              _hideEmergencyOptions();
                            },
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (selectedSubtype == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Selecciona un subtipo para continuar')),
                                );
                                return;
                              }
                              if (requiresOtherDetail && otherController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Describe el caso para la opción Otro')),
                                );
                                return;
                              }
                              final customDetailValue = otherController.text.trim();
                              Navigator.of(ctx).pop();
                              otherController.dispose();
                              _hideEmergencyOptions();
                              _showSuccessSnackBar(
                                emergencyType,
                                selectedCommunities,
                                isAnonymous: isAnonymous,
                                subtype: selectedSubtype!,
                                customDetail: customDetailValue,
                                attachmentPlaceholders: List<String>.from(photoPlaceholders),
                              );
                            },
                            child: Text(AppLocalizations.of(context)!.sendAlert),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSuccessSnackBar(
    String emergencyType,
    List<Map<String, dynamic>> selectedCommunities, {
    required bool isAnonymous,
    required String subtype,
    required String customDetail,
    required List<String> attachmentPlaceholders,
  }) async {
    final alertType = emergencyType;
    
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Enviando a ${selectedCommunities.length} comunidad${selectedCommunities.length > 1 ? 'es' : ''}...',
              ),
            ),
          ],
        ),
        backgroundColor: _primaryDark,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.fromLTRB(12, 12, 12, (bottomInset + 12).clamp(12.0, 40.0)),
      ),
    );

    // ── ONE call → ONE Firestore document with all destinations ───────────────
    final communityIds = selectedCommunities.map((c) => c['id'] as String).toList();
    final success = await _alertController.sendSwipedAlert(
      alertType: alertType,
      isAnonymous: isAnonymous,
      communityIds: communityIds,
      subtype: subtype,
      customDetail: customDetail.isEmpty ? null : customDetail,
      attachmentPlaceholders: attachmentPlaceholders,
    );
    final int successCount = success ? communityIds.length : 0;

    // Persist selection so the same communities are pre-selected next time.
    if (success) {
      _swipeConfig.setCommunitiesForType(alertType, communityIds);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    if (successCount > 0) {
      final screenWidth = MediaQuery.of(context).size.width;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF007AFF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.alertSent,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Enviada a $successCount comunidad${successCount > 1 ? 'es' : ''}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: _primaryDark,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(screenWidth < 400 ? 8 : 16),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSendingAlert),
          backgroundColor: _danger,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _hideEmergencyOptions() {
    setState(() {
      _showEmergencyOptions = false;
      _currentEmergencyType = '';
      _dragOffset = Offset.zero;
      _showDragFeedback = false;
      _currentDragDirection = null;
    });
    _animationController.reverse();
  }

  // ---------------------------------------------------------------------------
  // Direction detection — corrects Flutter's Y-axis (positive = down)
  // so that swiping UP maps to 'up', swiping DOWN maps to 'down', etc.
  // ---------------------------------------------------------------------------
  String _getDirection(Offset offset) {
    final distance = offset.distance;
    if (distance < 25) return '';

    // Negate dy: Flutter's Y axis is positive-downward, so dy<0 means UP.
    // Without correction atan2(dy,dx) maps swipe-up to 'down' and vice-versa.
    final corrected = Offset(offset.dx, -offset.dy);
    final angle = corrected.direction;
    final deg = (angle * 180 / math.pi + 360) % 360;

    if (deg >= 337.5 || deg < 22.5)   return 'right';
    if (deg >= 22.5  && deg < 67.5)   return 'upRight';
    if (deg >= 67.5  && deg < 112.5)  return 'up';
    if (deg >= 112.5 && deg < 157.5)  return 'upLeft';
    if (deg >= 157.5 && deg < 202.5)  return 'left';
    if (deg >= 202.5 && deg < 247.5)  return 'downLeft';
    if (deg >= 247.5 && deg < 292.5)  return 'down';
    if (deg >= 292.5 && deg < 337.5)  return 'downRight';
    return '';
  }

  // ---------------------------------------------------------------------------
  // Radial angle map: direction key → angle in radians (for label placement)
  // These are SCREEN angles (positive Y = down in Flutter canvas)
  // ---------------------------------------------------------------------------
  static const Map<String, double> _dirAngles = {
    'up':        -math.pi / 2,       // -90° (top)
    'upRight':   -math.pi / 4,       // -45°
    'right':      0.0,               //   0° (right)
    'downRight':  math.pi / 4,       //  45°
    'down':       math.pi / 2,       //  90° (bottom)
    'downLeft':   3 * math.pi / 4,   // 135°
    'left':       math.pi,           // 180° (left)
    'upLeft':    -3 * math.pi / 4,   // -135°
  };


  // ===========================================================================
  // BUILD — Premium radial swipe menu
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        HapticFeedback.lightImpact();
        setState(() {
          _dragOffset = Offset.zero;
          _isGestureActive = false;
          _showDragFeedback = false;
          _currentDragDirection = null;
        });
      },
      onPanUpdate: (details) {
        _dragOffset += details.delta;
        final dir = _getDirection(_dragOffset);
        if (dir != _currentDragDirection) {
          if (dir.isNotEmpty) HapticFeedback.selectionClick();
          setState(() {
            _currentDragDirection = dir;
            _showDragFeedback = dir.isNotEmpty;
          });
        }
      },
      onPanEnd: (_) {
        if (_currentDragDirection != null && _currentDragDirection!.isNotEmpty) {
          _handleGesture(_currentDragDirection!);
        }
        setState(() {
          _dragOffset = Offset.zero;
          _showDragFeedback = false;
          _currentDragDirection = null;
        });
      },
      child: LayoutBuilder(
        builder: (ctx, constraints) => _RadialMenu(
          availableWidth: constraints.maxWidth.isFinite ? constraints.maxWidth : 320,
          availableHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 320,
          dirAngles: _dirAngles,
          currentDragDirection: _currentDragDirection,
          showDragFeedback: _showDragFeedback,
          showEmergencyOptions: _showEmergencyOptions,
          currentEmergencyType: _currentEmergencyType,
          scaleAnimation: _scaleAnimation,
          onTapCenter: _sendQuickAlert,
        ),
      ),
    );
  }
}

// =============================================================================
// _RadialMenu — Stateless visual layer for the radial swipe interface
//
// Sizing strategy:
//   1. Take the smaller of available width/height as `available`
//   2. Button = 28% of available (clamped 56–110) — deliberately compact
//   3. Labels = 20%/15% of available (clamped) — readable first
//   4. Orbit = 72% of the gap between button edge and widget edge
//   5. ClipRect prevents any visual overlay with adjacent sections
// =============================================================================

class _RadialMenu extends StatelessWidget {
  final double availableWidth;
  final double availableHeight;
  final Map<String, double> dirAngles;
  final String? currentDragDirection;
  final bool showDragFeedback;
  final bool showEmergencyOptions;
  final String currentEmergencyType;
  final Animation<double> scaleAnimation;
  final VoidCallback onTapCenter;

  const _RadialMenu({
    required this.availableWidth,
    required this.availableHeight,
    required this.dirAngles,
    required this.currentDragDirection,
    required this.showDragFeedback,
    required this.showEmergencyOptions,
    required this.currentEmergencyType,
    required this.scaleAnimation,
    required this.onTapCenter,
  });

  @override
  Widget build(BuildContext context) {
    // ── Responsive sizing ─────────────────────────────────────────────────
    // Use the SMALLER dimension so nothing can ever overflow.
    final available = math.min(availableWidth, availableHeight).clamp(140.0, 420.0);

    // Central button: compact — 28% of available space, deliberately small
    // so labels get more room and the drag gesture feels intentional.
    final btnSize = (available * 0.28).clamp(56.0, 110.0);

    // Label chip dimensions — slightly larger relative to space for readability
    final labelW = (available * 0.20).clamp(48.0, 84.0);
    final labelH = (available * 0.15).clamp(36.0, 62.0);

    // Orbit radius: push labels outward. Use 70% of the distance between
    // button edge and widget edge so labels sit nearer the perimeter.
    final innerEdge = btnSize / 2 + 4.0;
    final outerEdge = (available / 2) - (labelH * 0.58);
    final orbit = innerEdge + (outerEdge - innerEdge) * 0.72;

    final cx = availableWidth / 2;
    final cy = availableHeight / 2;

    return SizedBox(
      width: availableWidth,
      height: availableHeight,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          alignment: Alignment.center,
          children: [
            // ── 1. Orbit ring (subtle, during drag) ────────────────────────
            if (showDragFeedback)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _OrbitPainter(
                      center: Offset(cx, cy),
                      radius: orbit,
                      color: Colors.grey.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ),

            // ── 2. Radial labels — always visible, never under the finger ─
            ...dirAngles.entries.map((e) => _buildLabel(
                  context: context,
                  dir: e.key,
                  angle: e.value,
                  orbit: orbit,
                  cx: cx,
                  cy: cy,
                  labelW: labelW,
                  labelH: labelH,
                )),

            // ── 3. Central HELP button ────────────────────────────────────
            Center(
              child: AnimatedBuilder(
                animation: scaleAnimation,
                builder: (_, __) => Transform.scale(
                  scale: showEmergencyOptions ? scaleAnimation.value : 1.0,
                  child: _CenterButton(
                    btnSize: btnSize,
                    showDragFeedback: showDragFeedback,
                    currentDragDirection: currentDragDirection,
                    showEmergencyOptions: showEmergencyOptions,
                    currentEmergencyType: currentEmergencyType,
                    onTap: onTapCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel({
    required BuildContext context,
    required String dir,
    required double angle,
    required double orbit,
    required double cx,
    required double cy,
    required double labelW,
    required double labelH,
  }) {
    final typeData = EmergencyTypes.getTypeByDirection(dir);
    if (typeData == null) return const SizedBox.shrink();

    final isSelected = showDragFeedback && currentDragDirection == dir;
    final baseColor = typeData['color'] as Color;
    final icon = typeData['icon'] as IconData;
    final name = EmergencyTypes.getTranslatedType(typeData['type'] as String, context);

    final dx = orbit * math.cos(angle);
    final dy = orbit * math.sin(angle);

    final iconSz = (labelH * 0.30).clamp(11.0, 20.0);
    final fontSize = (labelW * 0.12).clamp(7.0, 11.0);
    final radius = labelH * 0.26;

    return Positioned(
      left: cx + dx - labelW / 2,
      top: cy + dy - labelH / 2,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: labelW,
          height: labelH,
          decoration: BoxDecoration(
            color: isSelected
                ? baseColor.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isSelected
                  ? baseColor.withValues(alpha: 0.8)
                  : const Color(0xFFE0E0E5),
              width: isSelected ? 1.8 : 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.30),
                      blurRadius: 14,
                      spreadRadius: 1,
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 1.5),
                    )
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  icon,
                  key: ValueKey('$dir-$isSelected'),
                  size: iconSz,
                  color: isSelected ? baseColor : const Color(0xFF8E8E93),
                ),
              ),
              SizedBox(height: labelH * 0.04),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: labelW * 0.06),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? baseColor : const Color(0xFF636366),
                    height: 1.1,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _CenterButton — the pulsing HELP circle
// =============================================================================

class _CenterButton extends StatefulWidget {
  final double btnSize;
  final bool showDragFeedback;
  final String? currentDragDirection;
  final bool showEmergencyOptions;
  final String currentEmergencyType;
  final VoidCallback onTap;

  const _CenterButton({
    required this.btnSize,
    required this.showDragFeedback,
    required this.currentDragDirection,
    required this.showEmergencyOptions,
    required this.currentEmergencyType,
    required this.onTap,
  });

  @override
  State<_CenterButton> createState() => _CenterButtonState();
}

class _CenterButtonState extends State<_CenterButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.btnSize;

    // Resolve active direction color
    Color accentColor = const Color(0xFFFF3B30);
    if (widget.showDragFeedback && widget.currentDragDirection != null) {
      final td = EmergencyTypes.getTypeByDirection(widget.currentDragDirection!);
      if (td != null) accentColor = td['color'] as Color;
    }

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) {
        final scale = widget.showDragFeedback ? 1.0 : _pulseAnim.value;
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.35),
            radius: 0.9,
            colors: widget.showDragFeedback
                ? [
                    accentColor.withValues(alpha: 0.88),
                    accentColor,
                  ]
                : [
                    const Color(0xFFFF6B6B),
                    const Color(0xFFFF3B30),
                  ],
          ),
          boxShadow: [
            // Primary colored shadow
            BoxShadow(
              color: (widget.showDragFeedback ? accentColor : const Color(0xFFFF3B30))
                  .withValues(alpha: widget.showDragFeedback ? 0.50 : 0.35),
              blurRadius: size * 0.20,
              spreadRadius: widget.showDragFeedback ? size * 0.04 : 0,
              offset: Offset(0, size * 0.05),
            ),
            // Subtle white top highlight (depth illusion)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.18),
              blurRadius: size * 0.04,
              spreadRadius: -size * 0.02,
              offset: Offset(-size * 0.03, -size * 0.03),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(size / 2),
            splashColor: Colors.white.withValues(alpha: 0.15),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            child: Center(child: _buildContent(context, size)),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double size) {
    // ── Confirmed emergency ────────────────────────────────────────────────
    if (widget.showEmergencyOptions && widget.currentEmergencyType.isNotEmpty) {
      final td = EmergencyTypes.getTypeByDirection(widget.currentEmergencyType);
      if (td != null) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(td['icon'] as IconData, color: Colors.white, size: size * 0.26),
            SizedBox(height: size * 0.03),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.1),
              child: Text(
                EmergencyTypes.getTranslatedType(td['type'] as String, context),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.09,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
            ),
          ],
        );
      }
    }

    // ── Mid-drag: show icon of hovered option ─────────────────────────────
    if (widget.showDragFeedback && widget.currentDragDirection != null) {
      final td = EmergencyTypes.getTypeByDirection(widget.currentDragDirection!);
      if (td != null) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: Icon(
            td['icon'] as IconData,
            key: ValueKey(widget.currentDragDirection),
            color: Colors.white,
            size: size * 0.32,
          ),
        );
      }
    }

    // ── Idle: HELP text with swipe hint ───────────────────────────────────
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppLocalizations.of(context)!.help,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            height: 1.0,
          ),
        ),
        SizedBox(height: size * 0.035),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swipe_rounded,
              color: Colors.white.withValues(alpha: 0.55),
              size: size * 0.11,
            ),
            SizedBox(width: size * 0.02),
            Text(
              AppLocalizations.of(context)!.drag,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: size * 0.075,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// _OrbitPainter — thin dashed ring shown during drag
// =============================================================================

class _OrbitPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;

  const _OrbitPainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const segments = 24;
    const gap = 0.22;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < segments; i++) {
      final start = (i / segments) * 2 * math.pi;
      final end = start + (1 - gap) * (2 * math.pi / segments);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        end - start,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.center != center || old.radius != radius || old.color != color;
}
