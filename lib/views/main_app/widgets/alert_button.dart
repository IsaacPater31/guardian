import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:guardian/core/alert_detail_catalog.dart';
import 'package:guardian/handlers/alert_handler.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/services/alert_attachments_service.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/swipe_alert_config_service.dart';
import 'package:guardian/services/quick_alert_config_service.dart';
import 'package:guardian/views/main_app/settings_view.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

/// Paleta y métricas tipo iOS (legibilidad, aire, profesional).
abstract final class _AppleEmergencyUX {
  static const Color labelPrimary = Color(0xFF1C1C1E);
  static const Color labelSecondary = Color(0xFF8E8E93);
  static const Color separator = Color(0xFFE5E5EA);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color accentGreen = Color(0xFF34C759);
  static const Color accentBlue = Color(0xFF007AFF);
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

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

  /// Lienzo amplio: [FittedBox] lo reduce para caber en pantalla → efecto “zoom alejado”
  /// en todas las resoluciones (más aire izquierda/derecha, menos amontonado).
  /// Lienzo lógico del menú radial; `FittedBox` lo escala al `Expanded` de la home.
  static const double _kRadialCanvas = 472.0;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  bool _showEmergencyOptions = false;
  String _currentEmergencyType = '';
  bool _isGestureActive = false;
  
  Offset _dragOffset = Offset.zero;
  
  String? _currentDragDirection;
  bool _showDragFeedback = false;
  
  final AlertHandler _alertHandler = AlertHandler();
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

    // AlertHandler → AlertService → QuickAlertConfigService for destinations
    // internally and sends to all of them in a single batch — just call it once.
    final ok = await _alertHandler.sendQuickAlert(
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
        if (!mounted) return;
        if (selected != null && selected.isNotEmpty) {
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
      if (!mounted) return;
      if (selected != null && selected.isNotEmpty) {
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.noCommunitiesAvailableSnack),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
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
            final l10n = AppLocalizations.of(context)!;
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
                            l10n.selectCommunitiesDialogTitle,
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
                      l10n.selectCommunitiesSubtitle,
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
                                l10n.continueAction,
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
        final l10n = AppLocalizations.of(context)!;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorLoadingCommunitiesDetail}: $e'),
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
    final FocusNode otherFocus = FocusNode();
    final pickedImages = <XFile>[];
    File? audioFile;
    var isRecording = false;
    var recordElapsedSec = 0;
    Timer? recordCapTimer;
    Timer? recordUiTimer;
    AudioRecorder? recorder;
    final picker = ImagePicker();
    final attachments = AlertAttachmentsService.instance;

    Future<void> stopRecording(StateSetter setDialogState) async {
      recordCapTimer?.cancel();
      recordUiTimer?.cancel();
      recordCapTimer = null;
      recordUiTimer = null;
      final r = recorder;
      recorder = null;
      if (r == null) {
        setDialogState(() => isRecording = false);
        return;
      }
      try {
        final path = await r.stop();
        await r.dispose();
        if (path != null && path.isNotEmpty) {
          audioFile = File(path);
        }
      } catch (_) {
        await r.dispose();
      }
      setDialogState(() {
        isRecording = false;
        recordElapsedSec = 0;
      });
    }

    Future<void> startRecording(StateSetter setDialogState) async {
      if (isRecording) return;
      final r = AudioRecorder();
      try {
        if (!await r.hasPermission()) {
          await r.dispose();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.microphonePermissionSnack)),
          );
          return;
        }
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/alert_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await r.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
          path: path,
        );
        recorder = r;
        setDialogState(() {
          isRecording = true;
          recordElapsedSec = 0;
        });
        recordUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          setDialogState(() => recordElapsedSec++);
        });
        recordCapTimer = Timer(const Duration(seconds: 10), () {
          stopRecording(setDialogState);
        });
      } catch (e) {
        await r.dispose();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.recordingFailedWithError('$e'))),
        );
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final l10n = AppLocalizations.of(ctx)!;
          final requiresOtherDetail = selectedSubtype != null &&
              AlertDetailCatalog.subtypeRequiresDetail(emergencyType, selectedSubtype!);

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
                          onPressed: () async {
                            await stopRecording(setDialogState);
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            otherFocus.dispose();
                            otherController.dispose();
                            _showCommunitySelectionDialog(emergencyType).then((selection) {
                              if (!mounted) return;
                              if (selection != null && selection.isNotEmpty) {
                                _showFinalConfirmationDialog(emergencyType, selection);
                              } else {
                                _hideEmergencyOptions();
                              }
                            });
                          },
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: Text(
                            l10n.alertDetailSheetTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
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
                              '${l10n.selectedCommunitiesPrefix} ${selectedCommunities.map((c) => c['name']).join(', ')}',
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(l10n.subtypeOrReasonLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                              if (value == null) return;
                              setDialogState(() {
                                selectedSubtype = value;
                              });
                              if (value == AlertDetailCatalog.otherSubtypeId) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (otherFocus.canRequestFocus) {
                                    otherFocus.requestFocus();
                                  }
                                });
                              }
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
                              focusNode: otherFocus,
                              minLines: 2,
                              maxLines: 4,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                labelText: l10n.describeCaseLabel,
                                hintText: l10n.describeCaseHint,
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
                            title: Text(l10n.sendAsAnonymousTitle),
                            subtitle: Text(l10n.sendAsAnonymousSubtitle),
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
                                Text(
                                  l10n.photosAndAudioSection,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: _primary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.photosAndAudioPolicy(AlertAttachmentsService.maxImages),
                                  style: TextStyle(fontSize: 12.5, color: Colors.grey[800]),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: pickedImages.length >= AlertAttachmentsService.maxImages
                                          ? null
                                          : () async {
                                              final x = await picker.pickImage(
                                                source: ImageSource.gallery,
                                                maxWidth: 1400,
                                                imageQuality: 78,
                                              );
                                              if (x == null) return;
                                              setDialogState(() {
                                                if (pickedImages.length < AlertAttachmentsService.maxImages) {
                                                  pickedImages.add(x);
                                                }
                                              });
                                            },
                                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                                      label: Text(l10n.photoGallery),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: pickedImages.length >= AlertAttachmentsService.maxImages
                                          ? null
                                          : () async {
                                              final x = await picker.pickImage(
                                                source: ImageSource.camera,
                                                maxWidth: 1400,
                                                imageQuality: 78,
                                              );
                                              if (x == null) return;
                                              setDialogState(() {
                                                if (pickedImages.length < AlertAttachmentsService.maxImages) {
                                                  pickedImages.add(x);
                                                }
                                              });
                                            },
                                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                                      label: Text(l10n.photoCamera),
                                    ),
                                  ],
                                ),
                                if (pickedImages.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 88,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: pickedImages.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                                      itemBuilder: (context, i) {
                                        final path = pickedImages[i].path;
                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  showDialog<void>(
                                                    context: context,
                                                    builder: (c) => Dialog(
                                                      backgroundColor: Colors.black,
                                                      insetPadding: const EdgeInsets.all(16),
                                                      child: InteractiveViewer(
                                                        minScale: 0.5,
                                                        maxScale: 4,
                                                        child: Image.file(
                                                          File(path),
                                                          fit: BoxFit.contain,
                                                          errorBuilder: (_, __, ___) => Padding(
                                                            padding: const EdgeInsets.all(24),
                                                            child: Icon(Icons.broken_image_outlined,
                                                                color: Colors.grey[400], size: 48),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                                borderRadius: BorderRadius.circular(10),
                                                child: Tooltip(
                                                  message: l10n.photoChipLabel(i + 1),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: SizedBox(
                                                      width: 80,
                                                      height: 80,
                                                      child: Image.file(
                                                        File(path),
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => ColoredBox(
                                                          color: Colors.grey.shade300,
                                                          child: Icon(Icons.broken_image_outlined,
                                                              color: Colors.grey.shade600),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: -4,
                                              right: -4,
                                              child: Material(
                                                color: Colors.black87,
                                                shape: const CircleBorder(),
                                                clipBehavior: Clip.antiAlias,
                                                child: InkWell(
                                                  onTap: () => setDialogState(() => pickedImages.removeAt(i)),
                                                  customBorder: const CircleBorder(),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Icon(Icons.close, size: 16, color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      isRecording ? Icons.fiber_manual_record : Icons.mic_none_rounded,
                                      color: isRecording ? Colors.red : _primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isRecording
                                            ? l10n.recordingProgress(recordElapsedSec)
                                            : (audioFile != null
                                                ? l10n.audioReadyToSend
                                                : l10n.audioOptionalMaxTen),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: isRecording
                                            ? () => stopRecording(setDialogState)
                                            : () => startRecording(setDialogState),
                                        icon: Icon(isRecording ? Icons.stop : Icons.mic),
                                        label: Text(isRecording ? l10n.stopRecording : l10n.startRecording),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (audioFile != null)
                                      TextButton(
                                        onPressed: () => setDialogState(() => audioFile = null),
                                        child: Text(l10n.removeAudio),
                                      ),
                                  ],
                                ),
                                if (audioFile != null) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _LocalAudioPreview(
                                      key: ValueKey(audioFile!.path),
                                      file: audioFile!,
                                      listenLabel: l10n.attachmentListenPreview,
                                      pauseLabel: l10n.attachmentPausePreview,
                                    ),
                                  ),
                                ],
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
                            onPressed: () async {
                              await stopRecording(setDialogState);
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              otherFocus.dispose();
                              otherController.dispose();
                              if (mounted) _hideEmergencyOptions();
                            },
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (selectedSubtype == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.selectSubtypeRequired)),
                                );
                                return;
                              }
                              if (requiresOtherDetail && otherController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.describeOtherCaseRequired)),
                                );
                                return;
                              }
                              await stopRecording(setDialogState);
                              if (!ctx.mounted) return;

                              final customDetailValue = otherController.text.trim();
                              final prepared = await attachments.prepareForFirestore(
                                pickedImages,
                                audioFile,
                              );
                              final ph = List<String>.from(prepared.notes);

                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              otherFocus.dispose();
                              otherController.dispose();
                              if (mounted) _hideEmergencyOptions();
                              await _showSuccessSnackBar(
                                emergencyType,
                                selectedCommunities,
                                isAnonymous: isAnonymous,
                                subtype: selectedSubtype!,
                                customDetail: customDetailValue,
                                attachmentPlaceholders: ph,
                                imageBase64:
                                    prepared.imageBase64.isEmpty ? null : prepared.imageBase64,
                                audioBase64: prepared.audioBase64,
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

  Future<void> _showSuccessSnackBar(
    String emergencyType,
    List<Map<String, dynamic>> selectedCommunities, {
    required bool isAnonymous,
    required String subtype,
    required String customDetail,
    required List<String> attachmentPlaceholders,
    List<String>? imageBase64,
    String? audioBase64,
  }) async {
    final alertType = emergencyType;
    final l10n = AppLocalizations.of(context)!;
    final n = selectedCommunities.length;
    final sendingLine = n == 1
        ? l10n.alertSendingToOne
        : l10n.alertSendingToMany(n);
    
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
              child: Text(sendingLine),
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
    final success = await _alertHandler.sendSwipedAlert(
      alertType: alertType,
      isAnonymous: isAnonymous,
      communityIds: communityIds,
      subtype: subtype,
      customDetail: customDetail.isEmpty ? null : customDetail,
      attachmentPlaceholders: attachmentPlaceholders,
      imageBase64: imageBase64,
      audioBase64: audioBase64,
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
      final okL10n = AppLocalizations.of(context)!;
      final sentLine = successCount == 1
          ? okL10n.alertSentToOneCommunity
          : okL10n.alertSentToManyCommunities(successCount);
      
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
                        okL10n.alertSent,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        sentLine,
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
    if (!mounted) return;
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
  // Cinco direcciones (estrella): la más cercana en ángulo al gesto corregido.
  // ---------------------------------------------------------------------------
  String _getDirection(Offset offset) {
    final distance = offset.distance;
    if (distance < 22) return '';

    // Misma convención que al pintar chips, pero con Y invertida respecto a la
    // pantalla: hacia abajo-izquierda en pantalla → ángulo -3π/4 (no +3π/4).
    final corrected = Offset(offset.dx, -offset.dy);
    final a = corrected.direction;

    const centers = <String, double>{
      'right': 0,
      'downRight': -math.pi / 4,
      'downLeft': -3 * math.pi / 4,
      'left': math.pi,
      'up': math.pi / 2,
    };

    double normDelta(double x, double c) {
      var d = x - c;
      while (d > math.pi) {
        d -= 2 * math.pi;
      }
      while (d < -math.pi) {
        d += 2 * math.pi;
      }
      return d.abs();
    }

    var best = '';
    var bestDiff = 999.0;
    for (final e in centers.entries) {
      final d = normDelta(a, e.value);
      if (d < bestDiff) {
        bestDiff = d;
        best = e.key;
      }
    }
    if (bestDiff > 0.72) return '';
    return best;
  }

  /// Ángulos en radianes para posicionar chips (Y hacia abajo en pantalla).
  static const Map<String, double> _dirAngles = {
    'up': -math.pi / 2,
    'right': 0.0,
    'downRight': math.pi / 4,
    'downLeft': 3 * math.pi / 4,
    'left': math.pi,
  };


  // ===========================================================================
  // BUILD — Premium radial swipe menu
  // ===========================================================================

  EdgeInsets _radialSafePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    // Menos margen en pantallas amplias → el radial escala un poco más grande.
    final hx = w < 360 ? 6.0 : w < 420 ? 9.0 : w < 600 ? 11.0 : 10.0;
    final vyTop = h < 520 ? 6.0 : h < 700 ? 10.0 : 12.0;
    final vyBottom = h < 520 ? 4.0 : 8.0;
    return EdgeInsets.fromLTRB(hx, vyTop, hx, vyBottom);
  }

  @override
  Widget build(BuildContext context) {
    final radialPad = _radialSafePadding(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: radialPad,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: SizedBox(
                width: _kRadialCanvas,
                height: _kRadialCanvas,
                child: GestureDetector(
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
                    if (_currentDragDirection != null &&
                        _currentDragDirection!.isNotEmpty) {
                      _handleGesture(_currentDragDirection!);
                    }
                    setState(() {
                      _dragOffset = Offset.zero;
                      _showDragFeedback = false;
                      _currentDragDirection = null;
                    });
                  },
                  child: _RadialMenu(
                    availableWidth: _kRadialCanvas,
                    availableHeight: _kRadialCanvas,
                    dirAngles: _dirAngles,
                    currentDragDirection: _currentDragDirection,
                    showDragFeedback: _showDragFeedback,
                    showEmergencyOptions: _showEmergencyOptions,
                    currentEmergencyType: _currentEmergencyType,
                    scaleAnimation: _scaleAnimation,
                    onTapCenter: _sendQuickAlert,
                  ),
                ),
              ),
            ),
          ),
        ),
        _EventualityBottomStrip(
          onAmbiental: () {
            if (_showEmergencyOptions) return;
            _showEmergencyDialog(AlertDetailCatalog.environmental);
          },
          onPolicial: () {
            if (_showEmergencyOptions) return;
            _showEmergencyDialog(AlertDetailCatalog.police);
          },
        ),
      ],
    );
  }
}

/// Dos categorías inferiores — tarjetas blancas, borde fino y acento sistema (estilo iOS).
class _EventualityBottomStrip extends StatelessWidget {
  final VoidCallback onAmbiental;
  final VoidCallback onPolicial;

  const _EventualityBottomStrip({
    required this.onAmbiental,
    required this.onPolicial,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final hx = w < 360 ? 14.0 : w < 420 ? 18.0 : 22.0;
    final gap = w < 360 ? 10.0 : 12.0;
    final bottomExtra = mq.padding.bottom > 16 ? 4.0 : mq.padding.bottom > 0 ? 6.0 : 10.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hx, 4, hx, bottomExtra),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _AppleCategoryCard(
              icon: Icons.eco_rounded,
              title: l10n.eventualityEnvironmentalTitle,
              subtitle: l10n.eventualityEnvironmentalSubtitle,
              accent: _AppleEmergencyUX.accentGreen,
              onTap: onAmbiental,
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: _AppleCategoryCard(
              icon: Icons.local_police_rounded,
              title: l10n.eventualityPoliceTitle,
              subtitle: l10n.eventualityPoliceSubtitle,
              accent: _AppleEmergencyUX.accentBlue,
              onTap: onPolicial,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppleCategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _AppleCategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: accent, size: 19),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.28,
            color: _AppleEmergencyUX.labelPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            height: 1.2,
            letterSpacing: -0.08,
            color: _AppleEmergencyUX.labelSecondary,
          ),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: _AppleEmergencyUX.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _AppleEmergencyUX.separator,
          width: 0.5,
        ),
        boxShadow: _AppleEmergencyUX.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: accent.withValues(alpha: 0.15),
          highlightColor: accent.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                circle,
                const SizedBox(width: 10),
                Expanded(child: text),
              ],
            ),
          ),
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
//   2. Lienzo fijo 320 + FittedBox: misma composición en todos los tamaños (solo escala).
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
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final canvas = math.min(availableWidth, availableHeight);
    final available = canvas.clamp(148.0, 520.0);
    final isTiny = shortestSide < 340;
    final isCompact = shortestSide >= 340 && shortestSide < 400;

    final btnFrac = isTiny ? 0.205 : (isCompact ? 0.235 : 0.265);
    final btnSize = (available * btnFrac).clamp(52.0, 124.0);

    var labelW =
        (available * (isTiny ? 0.32 : 0.285)).clamp(76.0, 134.0);
    final labelH =
        (available * (isTiny ? 0.27 : 0.242)).clamp(58.0, 100.0);
    labelW = math.min(labelW, availableWidth * 0.44);

    final innerEdge = btnSize / 2 + 2.0;
    const edgePad = 7.0;
    // Órbita máx. por dirección: para cada ángulo, el chip alineado al eje debe caber
    // en el rectángulo (evita overflow diagonal y en “Emergencia Vial” a la derecha).
    double maxOrbitFromAngles() {
      var cap = double.infinity;
      for (final a in dirAngles.values) {
        final ca = math.cos(a).abs();
        final sa = math.sin(a).abs();
        var lim = double.infinity;
        if (ca > 1e-9) {
          lim = math.min(
            lim,
            (availableWidth / 2 - labelW / 2 - edgePad) / ca,
          );
        }
        if (sa > 1e-9) {
          lim = math.min(
            lim,
            (availableHeight / 2 - labelH / 2 - edgePad) / sa,
          );
        }
        cap = math.min(cap, lim);
      }
      if (!cap.isFinite || cap < innerEdge) return innerEdge;
      return cap.clamp(innerEdge, canvas);
    }

    final maxOrbit = maxOrbitFromAngles();
    final orbit =
        (innerEdge + (maxOrbit - innerEdge) * 0.93).clamp(innerEdge, maxOrbit);

    final cx = availableWidth / 2;
    final cy = availableHeight / 2;

    return SizedBox(
      width: availableWidth,
      height: availableHeight,
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
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

            // ── 2. Central HELP (debajo) — los chips van encima si hay solape ─
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

            // ── 3. Cinco categorías (encima del centro para leer nombres) ───
            ...dirAngles.entries.map((e) => _buildLabel(
                  context: context,
                  dir: e.key,
                  angle: e.value,
                  orbit: orbit,
                  cx: cx,
                  cy: cy,
                  labelW: labelW,
                  labelH: labelH,
                  isTinyLayout: isTiny,
                  isCompactLayout: isCompact,
                )),
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
    required bool isTinyLayout,
    required bool isCompactLayout,
  }) {
    final typeData = EmergencyTypes.getTypeByDirection(dir);
    if (typeData == null) return const SizedBox.shrink();

    final isSelected = showDragFeedback && currentDragDirection == dir;
    final baseColor = typeData['color'] as Color;
    final icon = typeData['icon'] as IconData;
    final name = EmergencyTypes.getTranslatedType(typeData['type'] as String, context);

    final dx = orbit * math.cos(angle);
    final dy = orbit * math.sin(angle);

    final iconSz = (labelH * 0.40).clamp(22.0, 38.0);
    final textTargetSize = isTinyLayout
        ? 12.0
        : isCompactLayout
            ? 13.25
            : 15.0;
    final radius = (labelH * 0.22).clamp(14.0, 22.0);
    final hPad = (labelW * 0.055).clamp(4.0, 8.0);
    // Reserva para borde decorativo (el hijo no debe superar el rect interior).
    const innerInset = 2.0;

    return Positioned(
      left: cx + dx - labelW / 2,
      top: cy + dy - labelH / 2,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: labelW,
          height: labelH,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: isSelected
                ? baseColor.withValues(alpha: 0.12)
                : _AppleEmergencyUX.cardSurface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isSelected
                  ? baseColor.withValues(alpha: 0.65)
                  : _AppleEmergencyUX.separator,
              width: isSelected ? 1.75 : 0.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.22),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(innerInset),
            child: LayoutBuilder(
              builder: (context, bc) {
                final innerW = bc.maxWidth;
                return FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: innerW),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            icon,
                            key: ValueKey('$dir-$isSelected'),
                            size: iconSz,
                            color: isSelected
                                ? baseColor
                                : _AppleEmergencyUX.labelSecondary,
                          ),
                        ),
                        SizedBox(height: math.max(2.0, labelH * 0.028)),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: math.max(0.0, hPad - innerInset),
                          ),
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: textTargetSize,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? baseColor
                                  : _AppleEmergencyUX.labelPrimary,
                              height: 1.12,
                              letterSpacing: -0.22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
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
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: size * 0.94),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  td['icon'] as IconData,
                  color: Colors.white,
                  size: math.max(18.0, size * 0.28),
                ),
                SizedBox(height: size * 0.028),
                Text(
                  EmergencyTypes.getTranslatedType(td['type'] as String, context),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: math.max(11.0, size * 0.095),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.15,
                    height: 1.12,
                  ),
                ),
              ],
            ),
          ),
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
            size: math.max(24.0, size * 0.36),
          ),
        );
      }
    }

    // ── Idle: HELP + swipe (doble FittedBox: el hub puede medir ~50px y el Row
    //    icono+texto no debe pedir más ancho que el círculo) ───────────────────
    final innerMaxW = size * 0.92;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: innerMaxW),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.help,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: math.max(11.0, size * 0.17),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                height: 1.0,
              ),
            ),
            SizedBox(height: math.max(2.0, size * 0.028)),
            SizedBox(
              width: innerMaxW,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swipe_rounded,
                      color: Colors.white.withValues(alpha: 0.58),
                      size: math.max(10.0, size * 0.11),
                    ),
                    SizedBox(width: math.max(2.0, size * 0.016)),
                    Text(
                      AppLocalizations.of(context)!.drag,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: math.max(9.5, size * 0.072),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _LocalAudioPreview — play/stop for recorded attachment before send
// =============================================================================

class _LocalAudioPreview extends StatefulWidget {
  final File file;
  final String listenLabel;
  final String pauseLabel;

  const _LocalAudioPreview({
    super.key,
    required this.file,
    required this.listenLabel,
    required this.pauseLabel,
  });

  @override
  State<_LocalAudioPreview> createState() => _LocalAudioPreviewState();
}

class _LocalAudioPreviewState extends State<_LocalAudioPreview> {
  late final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
    } else {
      await _player.play(DeviceFileSource(widget.file.path));
      if (mounted) setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _toggle,
      icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20),
      label: Text(_playing ? widget.pauseLabel : widget.listenLabel),
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
