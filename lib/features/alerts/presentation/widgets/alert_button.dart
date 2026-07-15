import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:guardian/features/alerts/application/audio_preview_service.dart';
import 'package:guardian/shared/catalog/alert_detail_catalog.dart';
import 'package:guardian/features/alerts/application/alert_handler.dart';
import 'package:guardian/features/communities/domain/community_model.dart';
import 'package:guardian/features/alerts/domain/emergency_types.dart';
import 'package:guardian/features/alerts/application/alert_attachments_service.dart';
import 'package:guardian/features/communities/application/community_service.dart';
import 'package:guardian/features/settings/application/swipe_alert_config_service.dart';
import 'package:guardian/features/settings/application/quick_alert_config_service.dart';
import 'package:guardian/features/settings/presentation/settings_view.dart';
import 'package:guardian/features/alerts/presentation/widgets/compact_alert/alert_compact_flow_interface.dart';
import 'package:guardian/features/alerts/presentation/widgets/compact_alert/help_types_horizontal_section.dart';
import 'package:guardian/features/alerts/presentation/widgets/compact_alert/slide_to_confirm_quick.dart';
import 'package:guardian/features/entity_reports/presentation/widgets/home_reports_section.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/shared/widgets/adaptive_fit_text.dart';


class AlertButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool compactTriggerMode;

  const AlertButton({
    super.key,
    required this.onPressed,
    this.compactTriggerMode = false,
  });

  @override
  State<AlertButton> createState() => _AlertButtonState();
}

class _AlertButtonState extends State<AlertButton>
    with TickerProviderStateMixin
    implements AlertCompactFlowInterface {
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

  final AlertHandler _alertHandler = AlertHandler();
  final CommunityService _communityService = CommunityService();
  final TypedAlertConfigService _typedConfig = TypedAlertConfigService();
  bool _isQuickTriggerBusy = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
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

  Future<void> _sendQuickAlert() async {
    HapticFeedback.heavyImpact();

    // Obtener los destinos configurados para alertas r�pidas
    final quickConfig = QuickAlertConfigService();
    final destinations = await quickConfig.getQuickAlertDestinations();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (destinations.isEmpty) {
      // Sin configuraci�n � redirigir a ajustes
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.settings, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(
                    context,
                  )!.quickAlertNoCommunitiesConfigured,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(milliseconds: 2200),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.quickAlertConfigureAction,
            textColor: const Color(0xFF007AFF),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuickAlertConfigView()),
              );
            },
          ),
        ),
      );
      return;
    }

    messenger.clearSnackBars();
    messenger.showSnackBar(
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
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    // AlertHandler ? AlertService ? QuickAlertConfigService for destinations
    // internally and sends to all of them in a single batch � just call it once.
    final ok = await _alertHandler.sendQuickAlert(
      alertType: EmergencyTypes.quickAlertType,
      isAnonymous: false,
    );
    final int successCount = ok ? destinations.length : 0;

    if (!mounted) return;
    messenger.clearSnackBars();
    if (!mounted) return;
    if (successCount > 0) {
      messenger.showSnackBar(
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
                    color: _primary,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        successCount == 1
                            ? AppLocalizations.of(
                                context,
                              )!.alertSentToOneCommunity
                            : AppLocalizations.of(
                                context,
                              )!.alertSentToManyCommunities(successCount),
                        style: const TextStyle(
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
          duration: const Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSendingAlert),
          backgroundColor: _danger,
          duration: const Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showEmergencyDialog(String emergencyType) async {
    final emergencyData = EmergencyTypes.getTypeByName(emergencyType);
    if (emergencyData == null || emergencyData.isEmpty) return;

    // 1. Verificar si hay comunidades configuradas por defecto para este tipo
    final configuredIds = await _typedConfig.getCommunitiesForType(
      emergencyType,
    );

    if (configuredIds != null && configuredIds.isNotEmpty) {
      // Hay configuraci�n guardada � obtener los datos de esas comunidades
      final allCommunities = await _typedConfig.getAvailableCommunities();
      final preselected = allCommunities
          .where((c) => c.id != null && configuredIds.contains(c.id!))
          .toList();

      if (preselected.isNotEmpty && mounted) {
        // Mostrar diag de confirmaci�n con las comunidades pre-seleccionadas
        final selected = await _showCommunitySelectionDialog(
          emergencyType,
          preSelectedIds: configuredIds.toSet(),
        );
        if (!mounted) return;
        if (selected != null && selected.isNotEmpty) {
          _showFinalConfirmationDialog(emergencyType, selected);
        } else {
          _hideEmergencyOptions();
        }
        return;
      }
    }

    // Sin config guardada � mostrar aviso y abrir configuraci�n
    if (mounted) {
      _hideEmergencyOptions();
      final typeName = EmergencyTypes.getTranslatedType(emergencyType, context);
      final l10n = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.settings, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.quickAlertConfigureTypeCommunities(typeName),
                      style: const TextStyle(fontSize: 13, height: 1.15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4DA3FF),
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TypedAlertConfigView(
                            initialAlertType: emergencyType,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      l10n.quickAlertConfigureAction,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          dismissDirection: DismissDirection.down,
          duration: const Duration(milliseconds: 3200),
        ),
      );
      Future.delayed(const Duration(milliseconds: 3600), () {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
      });
    }
  }

  Future<List<CommunityModel>?> _showCommunitySelectionDialog(
    String emergencyType, {
    Set<String> preSelectedIds = const {},
  }) async {
    if (!mounted) return null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
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

      // Pre-seleccionar seg�n configuraci�n o keyword
      final Set<String> selectedCommunityIds = Set<String>.from(preSelectedIds);

      final selectedCommunities = await showDialog<List<CommunityModel>>(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
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
                            final communityId = community.id!;
                            final isSelected = selectedCommunityIds.contains(
                              communityId,
                            );

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
                                    color: const Color(
                                      0xFF5AC8FA,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.people,
                                    color: const Color(0xFF5AC8FA),
                                    size: isSmall ? 17 : 20,
                                  ),
                                ),
                                title: Text(
                                  community.name,
                                  style: TextStyle(
                                    fontSize: isSmall ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? _primary : _primaryDark,
                                  ),
                                ),
                                subtitle: community.description != null
                                    ? Text(
                                        community.description ?? '',
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
                                        selectedCommunityIds.remove(
                                          communityId,
                                        );
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
                                            .where(
                                              (c) => selectedCommunityIds
                                                  .contains(c.id),
                                            )
                                            .toList();
                                        Navigator.of(context).pop(selected);
                                      }
                                    : null,
                                icon: Icon(
                                  Icons.arrow_forward,
                                  size: isSmall ? 16 : 18,
                                ),
                                label: Text(
                                  l10n.continueAction,
                                  style: TextStyle(
                                    fontSize: isSmall ? 13 : 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      selectedCommunityIds.isNotEmpty
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
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorLoadingCommunitiesDetail),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return null;
    }
  }

  void _showFinalConfirmationDialog(
    String emergencyType,
    List<CommunityModel> selectedCommunities,
  ) {
    final emergencyData = EmergencyTypes.getTypeByName(emergencyType);
    if (emergencyData == null) return;
    final translatedType = EmergencyTypes.getTranslatedType(
      emergencyType,
      context,
    );
    final subtypeOptions = AlertDetailCatalog.getSubtypes(emergencyType);
    String? selectedSubtype = subtypeOptions.isNotEmpty
        ? subtypeOptions.first.id
        : null;
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
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.microphonePermissionSnack,
              ),
            ),
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
      } catch (_) {
        await r.dispose();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.recordingFailed),
          ),
        );
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final l10n = AppLocalizations.of(ctx)!;
          final requiresOtherDetail =
              selectedSubtype != null &&
              AlertDetailCatalog.subtypeRequiresDetail(
                emergencyType,
                selectedSubtype!,
              );

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 20,
            ),
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
                            _showCommunitySelectionDialog(emergencyType).then((
                              selection,
                            ) {
                              if (!mounted) return;
                              if (selection != null && selection.isNotEmpty) {
                                _showFinalConfirmationDialog(
                                  emergencyType,
                                  selection,
                                );
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
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
                                  child: Icon(
                                    emergencyData['icon'],
                                    color: _danger,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  translatedType,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
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
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              '${l10n.selectedCommunitiesPrefix} ${selectedCommunities.map((c) => c.name).join(', ')}',
                              style: const TextStyle(fontSize: 13.5),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.subtypeOrReasonLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: selectedSubtype,
                            items: subtypeOptions
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option.id,
                                    child: Text(option.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedSubtype = value;
                              });
                              if (value == AlertDetailCatalog.otherSubtypeId) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
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
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(l10n.sendAsAnonymousTitle),
                            subtitle: Text(l10n.sendAsAnonymousSubtitle),
                            value: isAnonymous,
                            onChanged: (value) =>
                                setDialogState(() => isAnonymous = value),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.35),
                              ),
                              color: _primary.withValues(alpha: 0.08),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.photosAndAudioSection,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.photosAndAudioPolicy(
                                    AlertAttachmentsService.maxImages,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed:
                                          pickedImages.length >=
                                              AlertAttachmentsService.maxImages
                                          ? null
                                          : () async {
                                              final x = await picker.pickImage(
                                                source: ImageSource.gallery,
                                                maxWidth: 1400,
                                                imageQuality: 78,
                                              );
                                              if (x == null) return;
                                              setDialogState(() {
                                                if (pickedImages.length <
                                                    AlertAttachmentsService
                                                        .maxImages) {
                                                  pickedImages.add(x);
                                                }
                                              });
                                            },
                                      icon: const Icon(
                                        Icons.photo_library_outlined,
                                        size: 18,
                                      ),
                                      label: Text(l10n.photoGallery),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          pickedImages.length >=
                                              AlertAttachmentsService.maxImages
                                          ? null
                                          : () async {
                                              final x = await picker.pickImage(
                                                source: ImageSource.camera,
                                                maxWidth: 1400,
                                                imageQuality: 78,
                                              );
                                              if (x == null) return;
                                              setDialogState(() {
                                                if (pickedImages.length <
                                                    AlertAttachmentsService
                                                        .maxImages) {
                                                  pickedImages.add(x);
                                                }
                                              });
                                            },
                                      icon: const Icon(
                                        Icons.photo_camera_outlined,
                                        size: 18,
                                      ),
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
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 10),
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
                                                      backgroundColor:
                                                          Colors.black,
                                                      insetPadding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      child: InteractiveViewer(
                                                        minScale: 0.5,
                                                        maxScale: 4,
                                                        child: Image.file(
                                                          File(path),
                                                          fit: BoxFit.contain,
                                                          errorBuilder:
                                                              (
                                                                _,
                                                                __,
                                                                ___,
                                                              ) => Padding(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      24,
                                                                    ),
                                                                child: Icon(
                                                                  Icons
                                                                      .broken_image_outlined,
                                                                  color: Colors
                                                                      .grey[400],
                                                                  size: 48,
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Tooltip(
                                                  message: l10n.photoChipLabel(
                                                    i + 1,
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    child: SizedBox(
                                                      width: 80,
                                                      height: 80,
                                                      child: Image.file(
                                                        File(path),
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              _,
                                                              __,
                                                              ___,
                                                            ) => ColoredBox(
                                                              color: Colors
                                                                  .grey
                                                                  .shade300,
                                                              child: Icon(
                                                                Icons
                                                                    .broken_image_outlined,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                              ),
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
                                                  onTap: () => setDialogState(
                                                    () => pickedImages.removeAt(
                                                      i,
                                                    ),
                                                  ),
                                                  customBorder:
                                                      const CircleBorder(),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Icon(
                                                      Icons.close,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
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
                                      isRecording
                                          ? Icons.fiber_manual_record
                                          : Icons.mic_none_rounded,
                                      color: isRecording
                                          ? Colors.red
                                          : _primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isRecording
                                            ? l10n.recordingProgress(
                                                recordElapsedSec,
                                              )
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
                                            ? () =>
                                                  stopRecording(setDialogState)
                                            : () => startRecording(
                                                setDialogState,
                                              ),
                                        icon: Icon(
                                          isRecording ? Icons.stop : Icons.mic,
                                        ),
                                        label: Text(
                                          isRecording
                                              ? l10n.stopRecording
                                              : l10n.startRecording,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    if (audioFile != null) ...[
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: TextButton(
                                          onPressed: () => setDialogState(
                                            () => audioFile = null,
                                          ),
                                          child: Text(
                                            l10n.removeAudio,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                  SnackBar(
                                    content: Text(l10n.selectSubtypeRequired),
                                  ),
                                );
                                return;
                              }
                              if (requiresOtherDetail &&
                                  otherController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.describeOtherCaseRequired,
                                    ),
                                  ),
                                );
                                return;
                              }
                              await stopRecording(setDialogState);
                              if (!ctx.mounted) return;

                              final customDetailValue = otherController.text
                                  .trim();
                              final prepared = await attachments
                                  .prepareForFirestore(pickedImages, audioFile);
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
                                imageBase64: prepared.imageBase64.isEmpty
                                    ? null
                                    : prepared.imageBase64,
                                audioBase64: prepared.audioBase64,
                              );
                            },
                            child: Text(
                              AppLocalizations.of(context)!.sendAlert,
                            ),
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
    List<CommunityModel> selectedCommunities, {
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
    final readableType = EmergencyTypes.getTranslatedType(alertType, context);
    final sendingLine = n == 1
        ? '${l10n.alertSendingToOne} ($readableType)'
        : '${l10n.alertSendingToMany(n)} ($readableType)';

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
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
            Expanded(child: Text(sendingLine)),
          ],
        ),
        backgroundColor: _primaryDark,
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          (bottomInset + 12).clamp(12.0, 40.0),
        ),
      ),
    );

    // -- ONE call ? ONE Firestore document with all destinations ---------------
    final communityIds = selectedCommunities
        .map((c) => c.id!)
        .toList();
    final success = await _alertHandler.sendTypedAlert(
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
      _typedConfig.setCommunitiesForType(alertType, communityIds);
    }

    if (!mounted) return;
    messenger.clearSnackBars();

    if (successCount > 0) {
      final screenWidth = MediaQuery.of(context).size.width;
      final okL10n = AppLocalizations.of(context)!;
      final sentLine = successCount == 1
          ? okL10n.alertSentToOneCommunity
          : okL10n.alertSentToManyCommunities(successCount);

      messenger.showSnackBar(
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
                        '${okL10n.alertSent}: $readableType',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        sentLine,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: _primaryDark,
          duration: const Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(screenWidth < 400 ? 8 : 16),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSendingAlert),
          backgroundColor: _danger,
          duration: const Duration(milliseconds: 1800),
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
  // Seis direcciones (estrella): la m�s cercana en �ngulo al gesto corregido.
  // ---------------------------------------------------------------------------
  String _getDirection(
    Offset offset,
    double minPanDistance, {
    double maxAngleSlack = 0.72,
  }) {
    final distance = offset.distance;
    if (distance < minPanDistance) return '';

    // Misma convenci�n que al pintar chips, pero con Y invertida respecto a la
    // pantalla: hacia abajo-izquierda en pantalla ? �ngulo -3p/4 (no +3p/4).
    final corrected = Offset(offset.dx, -offset.dy);
    final a = corrected.direction;

    const centers = <String, double>{
      'right': 0,
      // Abajo: mismo rol (dcha / izq) que [_dirAngles], un poco m�s bajos en pantalla.
      'downRight': -5 * math.pi / 18,
      'downLeft': -13 * math.pi / 18,
      'left': math.pi,
      'upRight': 5 * math.pi / 18,
      'upLeft': 13 * math.pi / 18,
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
    if (bestDiff > maxAngleSlack) return '';
    // Sector superior: decidir lado por desplazamiento horizontal para evitar
    // ambiguedad cuando el gesto va casi vertical.
    if (a > 5 * math.pi / 18 && a < 13 * math.pi / 18) {
      return corrected.dx < 0 ? 'upLeft' : 'upRight';
    }
    return best;
  }

  /// �ngulos en radianes para posicionar chips (Y hacia abajo en pantalla).
  /// Arriba y abajo comparten columnas X (�50� / �130�), logrando
  /// alineaci�n vertical entre pares izquierdo/derecho.
  static const Map<String, double> _dirAngles = {
    'upLeft': -13 * math.pi / 18,
    'upRight': -5 * math.pi / 18,
    'right': 0.0,
    'downRight': 5 * math.pi / 18,
    'downLeft': 13 * math.pi / 18,
    'left': math.pi,
  };

  // ===========================================================================
  // BUILD � Premium radial swipe menu
  // ===========================================================================

  EdgeInsets _radialSafePadding(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final isLandscape = mq.orientation == Orientation.landscape;
    final viewPad = mq.viewPadding;
    final widthT = _fluidScale(w, inMin: 320, inMax: 1280);
    final heightT = _fluidScale(h, inMin: 480, inMax: 1100);
    final hx = (_lerpDouble(4.0, 12.0, widthT) * (isLandscape ? 0.92 : 1.0))
        .clamp(4.0, 12.0);
    var vyTop = _lerpDouble(4.0, 10.0, heightT);
    var vyBottom = _lerpDouble(2.0, 6.0, heightT);
    if (h > 640 && viewPad.top > 24) vyTop += 2;
    if (viewPad.bottom > 16) {
      vyBottom = math.max(vyBottom, viewPad.bottom * 0.35);
    }
    return EdgeInsets.fromLTRB(hx, vyTop, hx, vyBottom);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compactTriggerMode) {
      return _buildCompactTriggerLayout(context);
    }
    final radialPad = _radialSafePadding(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: radialPad,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 8 || constraints.maxHeight < 8) {
                  return const SizedBox.shrink();
                }
                final metrics = _RadialLayoutMetrics.from(context, constraints);
                final canvasSide = metrics.canvasSide;
                final panDeadZone = (canvasSide * 0.082).clamp(22.0, 48.0);
                final useW = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                final useH = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : MediaQuery.sizeOf(context).height;
                return SizedBox(
                  width: useW,
                  height: useH,
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
                      final dir = _getDirection(
                        _dragOffset,
                        panDeadZone,
                        maxAngleSlack: canvasSide < 292 ? 0.78 : 0.72,
                      );
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
                      metrics: metrics,
                      availableWidth: useW,
                      availableHeight: useH,
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
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _triggerQuickFromSlider() async {
    if (_isQuickTriggerBusy) return;
    setState(() => _isQuickTriggerBusy = true);
    try {
      await _sendQuickAlert();
    } finally {
      if (mounted) setState(() => _isQuickTriggerBusy = false);
    }
  }

  @override
  bool get isQuickTriggerBusy => _isQuickTriggerBusy;

  @override
  bool get isEmergencyFlowLocked => _showEmergencyOptions;

  @override
  Future<void> triggerQuickAlert() => _triggerQuickFromSlider();

  @override
  void openEmergencyFlow(String emergencyType) {
    _showEmergencyDialog(emergencyType);
  }

  Widget _buildCompactTriggerLayout(BuildContext context) {
    final quickTypes = <String>[
      AlertDetailCatalog.fire,
      AlertDetailCatalog.homeHelp,
      AlertDetailCatalog.health,
      AlertDetailCatalog.roadEmergency,
      AlertDetailCatalog.securityBreach,
      AlertDetailCatalog.harassment,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final t = _fluidScale(containerW, inMin: 300, inMax: 1100);
        final sectionTitleSize = _lerpDouble(17.0, 20.0, t).clamp(17.0, 20.0);
        final sectionGap = _lerpDouble(9.0, 14.0, t).clamp(9.0, 14.0);
        final rowGap = _lerpDouble(8.0, 12.0, t).clamp(8.0, 12.0);
        final cardWidth = _lerpDouble(98.0, 132.0, t).clamp(98.0, 132.0);
        final cardHeight = _lerpDouble(104.0, 128.0, t).clamp(104.0, 128.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SlideToConfirmQuick(
              isBusy: isQuickTriggerBusy,
              onConfirmed: triggerQuickAlert,
            ),
            HelpTypesHorizontalSection(
              title: '�Qu� tipo de ayuda necesitas?',
              titleSize: sectionTitleSize,
              topGap: sectionGap,
              rowGap: rowGap,
              cardHeight: cardHeight,
              cardWidth: cardWidth,
              compact: containerW < 420,
              quickTypes: quickTypes,
              flow: this,
            ),
            HomeReportsSection(
              titleSize: sectionTitleSize,
              topGap: sectionGap,
              rowGap: rowGap,
            ),
          ],
        );
      },
    );
  }
}

// --- merged from alert_button_layout.dart ---
double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

double _lerpDouble(double a, double b, double t) => a + (b - a) * _clamp01(t);

double _fluidScale(
  double input, {
  required double inMin,
  required double inMax,
}) {
  if (inMax <= inMin) return 0;
  return _clamp01((input - inMin) / (inMax - inMin));
}

/// Paleta y métricas tipo iOS (legibilidad, aire, profesional).
/// Métricas del menú radial derivadas del espacio disponible (responsive).
class _RadialLayoutMetrics {
  final double canvasSide;
  final double hubSize;
  final double labelW;
  final double labelH;
  final double radialGutter;
  final double edgePad;
  final double orbitFill;

  /// Radio mínimo del centro del chip: hub + gutter + mitad diagonal del chip.
  final double minOrbitRadius;
  final bool isTiny;
  final bool isCompact;
  final bool isTablet;

  const _RadialLayoutMetrics({
    required this.canvasSide,
    required this.hubSize,
    required this.labelW,
    required this.labelH,
    required this.radialGutter,
    required this.edgePad,
    required this.orbitFill,
    required this.minOrbitRadius,
    required this.isTiny,
    required this.isCompact,
    required this.isTablet,
  });

  factory _RadialLayoutMetrics.from(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final mq = MediaQuery.of(context);
    final deviceShortest = mq.size.shortestSide;
    final deviceWidth = mq.size.width;
    final landscape = mq.orientation == Orientation.landscape;
    final maxW = constraints.maxWidth;
    final maxH = constraints.maxHeight;
    final side = math.min(
      maxW.isFinite ? maxW : deviceWidth,
      maxH.isFinite ? maxH : mq.size.height,
    );

    if (!side.isFinite || side < 8) {
      return _RadialLayoutMetrics._tinyFallback();
    }

    final isTabletLike = isTabletish(deviceShortest, deviceWidth);
    // Lienzo radial: usar más área útil en tablets y anchos medianos.
    final canvasFactor = landscape && maxH < 300
        ? 0.91
        : isTabletLike
        ? 0.97
        : 0.955;
    final canvasMax = isTabletLike
        ? math.min(860.0, side)
        : math.min(620.0, side);
    final canvasSide = (side * canvasFactor).clamp(240.0, canvasMax);

    final layoutShortest = canvasSide;
    final isTiny = layoutShortest < 278 || deviceShortest < 328;
    final isCompact =
        !isTiny &&
        (layoutShortest < 392 ||
            (deviceShortest < 404 && deviceShortest >= 328));
    final isTablet = isTabletish(deviceShortest, deviceWidth);
    final isTabletLandscape = isTablet && landscape;
    final fluidT = _fluidScale(
      layoutShortest,
      inMin: 250,
      inMax: isTablet ? 860 : 620,
    );

    // Hub protagonista moderado: importante, sin dominar de forma exagerada.
    final hubFrac =
        (0.405 -
                (0.034 * fluidT) +
                (isTablet && !isTabletLandscape ? 0.006 : 0.0) +
                (isTiny ? -0.008 : 0.0))
            .clamp(0.35, 0.405);
    final hubSize = (canvasSide * hubFrac).clamp(
      isTiny ? 78.0 : 82.0,
      isTablet
          ? isTabletLandscape
                ? 204.0
                : 226.0
          : 180.0,
    );

    // Chips secundarios: +40% aprox en área (boost controlado, sin romper colisiones).
    const chipAreaBoost = 1.18; // ~1.18^2 = 1.39 (≈ +39% de área)
    var labelHFactor = _lerpDouble(
      isTiny ? 0.228 : 0.218,
      isTablet
          ? isTabletLandscape
                ? 0.188
                : 0.212
          : 0.198,
      fluidT,
    );
    var labelWFactor = _lerpDouble(
      isTiny ? 0.318 : 0.306,
      isTablet
          ? isTabletLandscape
                ? 0.276
                : 0.298
          : 0.278,
      fluidT,
    );
    if (isCompact && !isTablet) {
      labelWFactor *= 0.965;
    }
    var labelH = (canvasSide * labelHFactor).clamp(
      48.0,
      isTablet
          ? isTabletLandscape
                ? 96.0
                : 114.0
          : 80.0,
    );
    var labelW = (canvasSide * labelWFactor).clamp(
      74.0,
      isTablet
          ? isTabletLandscape
                ? 188.0
                : 196.0
          : 124.0,
    );
    labelH *= chipAreaBoost;
    labelW *= chipAreaBoost;
    if (isCompact && !isTablet) {
      // En tamaño mediano/compacto el problema principal es horizontal:
      // estrechar un poco el chip libera órbita sin perder legibilidad.
      labelW *= 0.92;
    }
    labelH = labelH.clamp(
      52.0,
      isTablet
          ? isTabletLandscape
                ? 108.0
                : 126.0
          : 92.0,
    );
    labelW = labelW.clamp(
      84.0,
      isTablet
          ? isTabletLandscape
                ? 214.0
                : 224.0
          : 148.0,
    );
    labelW = math.min(labelW, labelH * (isTablet ? 2.05 : 1.52));
    if (maxW.isFinite) {
      labelW = math.min(
        labelW,
        maxW *
            (isTablet
                ? isTabletLandscape
                      ? 0.32
                      : 0.36
                : 0.42),
      );
    }

    final radialGutterFactor = _lerpDouble(
      0.038,
      isTabletLandscape ? 0.027 : 0.031,
      fluidT,
    );
    final radialGutter = (layoutShortest * radialGutterFactor).clamp(
      6.5,
      isTabletLandscape ? 12.0 : 14.0,
    );
    final edgePad = (layoutShortest * 0.012).clamp(4.0, 10.0);

    // Distancia mínima para evitar colisiones, sin abrir exageradamente la órbita.
    final chipOrbitFactor =
        (_lerpDouble(
                  isCompact ? 0.56 : 0.54,
                  isTabletLandscape ? 0.45 : 0.48,
                  fluidT,
                ) +
                (isTiny ? 0.02 : 0.0))
            .clamp(0.45, 0.60);
    var minOrbitRadius =
        hubSize / 2 + radialGutter + math.max(labelW, labelH) * chipOrbitFactor;

    // Si no cabe el anillo, reducir solo chips (nunca el hub).
    final maxOrbitBudget = canvasSide * (isTabletLandscape ? 0.47 : 0.44);
    if (minOrbitRadius > maxOrbitBudget && minOrbitRadius > 0) {
      final scale = (maxOrbitBudget / minOrbitRadius).clamp(0.80, 1.0);
      labelH *= scale;
      labelW *= scale;
      labelW = math.min(labelW, labelH * (isTablet ? 2.05 : 1.52));
      minOrbitRadius =
          hubSize / 2 +
          radialGutter +
          math.max(labelW, labelH) * chipOrbitFactor;
    }

    return _RadialLayoutMetrics(
      canvasSide: canvasSide,
      hubSize: hubSize,
      labelW: labelW,
      labelH: labelH,
      radialGutter: radialGutter,
      edgePad: edgePad,
      orbitFill:
          (_lerpDouble(0.57, 0.50, fluidT) +
                  (isTablet && !isTabletLandscape ? 0.03 : 0.0) +
                  (isTiny ? 0.02 : 0.0))
              .clamp(0.49, 0.62),
      minOrbitRadius: minOrbitRadius,
      isTiny: isTiny,
      isCompact: isCompact,
      isTablet: isTablet,
    );
  }

  static bool isTabletish(double deviceShortest, double deviceWidth) =>
      deviceShortest >= 560 || deviceWidth >= 600;

  static _RadialLayoutMetrics _tinyFallback() {
    const hub = 84.0;
    const w = 78.0;
    const h = 52.0;
    const gutter = 9.0;
    return _RadialLayoutMetrics(
      canvasSide: 260,
      hubSize: hub,
      labelW: w,
      labelH: h,
      radialGutter: gutter,
      edgePad: 4,
      orbitFill: 0.58,
      minOrbitRadius: hub / 2 + gutter + math.max(w, h) * 0.54,
      isTiny: true,
      isCompact: false,
      isTablet: false,
    );
  }
}

abstract final class _AppleEmergencyUX {
  static const Color labelPrimary = Color(0xFF1C1C1E);
  static const Color labelSecondary = Color(0xFF8E8E93);
  static const Color separator = Color(0xFFE5E5EA);
  static const Color cardSurface = Color(0xFFFFFFFF);
}

// --- merged from alert_button_radial.dart ---
// =============================================================================
// _RadialMenu — Stateless visual layer for the radial swipe interface
//
// Sizing strategy:
//   1. `availableWidth/Height` vienen del [LayoutBuilder] de la home (espacio real).
//   2. Clases: tiny / compact / tablet según `layoutShortest` y `deviceShortest`.
//   3. Gutter y `edgePad` escalan con el lienzo; gesto: `panDeadZone` y `maxAngleSlack` en el padre.
// =============================================================================

class _RadialMenu extends StatelessWidget {
  final _RadialLayoutMetrics metrics;
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
    required this.metrics,
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
    final hubSize = metrics.hubSize;
    final labelW = metrics.labelW;
    final labelH = metrics.labelH;
    final isTiny = metrics.isTiny;
    final isCompact = metrics.isCompact;
    final isTablet = metrics.isTablet;

    final minOrbit = metrics.minOrbitRadius;
    final edgePad = metrics.edgePad;
    final labelBleedPad = isTiny
        ? 5.0
        : isCompact
        ? 4.0
        : isTablet
        ? 4.0
        : 4.5;
    final horizontalBleedPad = isCompact && !isTablet ? 2.0 : labelBleedPad;
    final verticalBleedPad = labelBleedPad;
    final orbitPullOut = isTiny
        ? 0.09
        : isCompact
        ? 0.12
        : isTablet
        ? 0.06
        : 0.07;
    final effectiveOrbitFill = (metrics.orbitFill + orbitPullOut).clamp(
      0.0,
      0.92,
    );

    double maxOrbitForAngle(double angle) {
      final ca = math.cos(angle).abs();
      final sa = math.sin(angle).abs();
      var lim = double.infinity;
      if (ca > 1e-9) {
        lim = math.min(
          lim,
          (availableWidth / 2 - labelW / 2 - edgePad - horizontalBleedPad) / ca,
        );
      }
      if (sa > 1e-9) {
        lim = math.min(
          lim,
          (availableHeight / 2 - labelH / 2 - edgePad - verticalBleedPad) / sa,
        );
      }
      if (!lim.isFinite || lim < minOrbit) return minOrbit;
      return lim;
    }

    final orbitByDir = <String, double>{
      for (final e in dirAngles.entries)
        e.key:
            (minOrbit +
                    math.max(0.0, maxOrbitForAngle(e.value) - minOrbit) *
                        effectiveOrbitFill)
                .clamp(minOrbit, maxOrbitForAngle(e.value)),
    };
    final orbitForRing = orbitByDir.values.isEmpty
        ? minOrbit
        : orbitByDir.values.reduce((a, b) => a + b) / orbitByDir.length;

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
                      radius: orbitForRing,
                      color: Colors.grey.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ),

            // ── 2. Chips secundarios (debajo del hub para no taparlo) ─────────
            ...dirAngles.entries.map(
              (e) => _buildLabel(
                context: context,
                dir: e.key,
                angle: e.value,
                orbit: orbitByDir[e.key] ?? minOrbit,
                cx: cx,
                cy: cy,
                availableWidth: availableWidth,
                availableHeight: availableHeight,
                labelW: labelW,
                labelH: labelH,
                safeInset: edgePad + labelBleedPad,
                isTinyLayout: isTiny,
                isCompactLayout: isCompact,
                isTabletLayout: isTablet,
              ),
            ),

            // ── 3. Hub Ayuda (protagonista, siempre encima) ───────────────────
            Center(
              child: AnimatedBuilder(
                animation: scaleAnimation,
                builder: (_, __) => Transform.scale(
                  scale: showEmergencyOptions ? scaleAnimation.value : 1.0,
                  child: _CenterButton(
                    btnSize: hubSize,
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
    required double availableWidth,
    required double availableHeight,
    required double labelW,
    required double labelH,
    required double safeInset,
    required bool isTinyLayout,
    required bool isCompactLayout,
    required bool isTabletLayout,
  }) {
    final typeData = EmergencyTypes.getTypeByDirection(dir);
    if (typeData == null) return const SizedBox.shrink();

    final isSelected = showDragFeedback && currentDragDirection == dir;
    final baseColor = typeData['color'] as Color;
    final icon = typeData['icon'] as IconData;
    final name = EmergencyTypes.getTranslatedType(
      typeData['type'] as String,
      context,
    );

    final dx = orbit * math.cos(angle);
    final dy = orbit * math.sin(angle);

    final iconSz = (labelH * 0.28).clamp(17.0, isTabletLayout ? 30.0 : 26.0);
    final rawFontSize = isTinyLayout
        ? 12.0
        : isCompactLayout
        ? 12.5
        : isTabletLayout
        ? 15.0
        : 14.0;
    final textTargetSize = math.min(
      MediaQuery.textScalerOf(context).scale(rawFontSize),
      labelH * 0.40,
    );
    final textMaxH = labelH * 0.48;
    final radius = (labelH * 0.20).clamp(10.0, 16.0);
    final hPad = (labelW * 0.04).clamp(3.0, 6.0);
    // Reserva para borde decorativo (el hijo no debe superar el rect interior).
    const innerInset = 2.0;

    final rawLeft = cx + dx - labelW / 2;
    final rawTop = cy + dy - labelH / 2;
    final minLeft = safeInset;
    final maxLeft = math.max(minLeft, availableWidth - labelW - safeInset);
    final minTop = safeInset;
    final maxTop = math.max(minTop, availableHeight - labelH - safeInset);
    final clampedLeft = rawLeft.clamp(minLeft, maxLeft).toDouble();
    final clampedTop = rawTop.clamp(minTop, maxTop).toDouble();

    return Positioned(
      left: clampedLeft,
      top: clampedTop,
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
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(innerInset),
            // Sin FittedBox: antes los textos cortos escalaban y Acoso/Sanitaria se veían más grandes.
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, __) {
                      final animatedColor = Color.lerp(
                        _AppleEmergencyUX.labelSecondary,
                        baseColor,
                        t,
                      )!;
                      final animatedSize = iconSz * (0.96 + (0.08 * t));
                      return Transform.scale(
                        scale: 1.0 + (0.06 * t),
                        child: Icon(
                          icon,
                          size: animatedSize,
                          color: animatedColor,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: math.max(1.0, labelH * 0.016)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: math.max(0.0, hPad - innerInset),
                    ),
                    child: AdaptiveFitText(
                      text: name,
                      maxWidth:
                          labelW -
                          2 * innerInset -
                          2 * math.max(0.0, hPad - innerInset),
                      maxHeight: textMaxH,
                      maxLines: isTinyLayout ? 1 : 2,
                      minFontSize: isTabletLayout ? 10.5 : 10.0,
                      style: TextStyle(
                        fontSize: textTargetSize,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? baseColor
                            : _AppleEmergencyUX.labelPrimary,
                        height: 1.05,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
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
    _pulseAnim = Tween<double>(
      begin: 0.97,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
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
      final td = EmergencyTypes.getTypeByDirection(
        widget.currentDragDirection!,
      );
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
                ? [accentColor.withValues(alpha: 0.88), accentColor]
                : [const Color(0xFFFF6B6B), const Color(0xFFFF3B30)],
          ),
          boxShadow: [
            // Primary colored shadow
            BoxShadow(
              color:
                  (widget.showDragFeedback
                          ? accentColor
                          : const Color(0xFFFF3B30))
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
        return Padding(
          padding: EdgeInsets.all(size * 0.06),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                td['icon'] as IconData,
                color: Colors.white,
                size: math.max(18.0, size * 0.26),
              ),
              SizedBox(height: size * 0.02),
              AdaptiveFitText(
                text: EmergencyTypes.getTranslatedType(
                  td['type'] as String,
                  context,
                ),
                maxWidth: size * 0.86,
                maxHeight: size * 0.34,
                maxLines: 2,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: math.max(11.0, size * 0.10),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.15,
                  height: 1.08,
                ),
              ),
            ],
          ),
        );
      }
    }

    // ── Mid-drag: show icon of hovered option ─────────────────────────────
    if (widget.showDragFeedback && widget.currentDragDirection != null) {
      final td = EmergencyTypes.getTypeByDirection(
        widget.currentDragDirection!,
      );
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
    final innerMaxW = size * 0.88;
    final innerMaxH = size * 0.42;
    return AdaptiveFitText(
      text: AppLocalizations.of(context)!.help,
      maxWidth: innerMaxW,
      maxHeight: innerMaxH,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: math.max(14.0, size * 0.22),
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        height: 1.0,
      ),
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

// --- merged from alert_button_audio_preview.dart ---
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
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    AudioPreviewService.setCompletionHandler(() {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    unawaited(AudioPreviewService.stop());
    AudioPreviewService.clearCompletionHandler();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await AudioPreviewService.stop();
      if (mounted) setState(() => _playing = false);
    } else {
      try {
        await AudioPreviewService.play(widget.file.path);
        if (mounted) setState(() => _playing = true);
      } on PlatformException {
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.audioPreviewFailed),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _toggle,
      icon: Icon(
        _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 20,
      ),
      label: Text(_playing ? widget.pauseLabel : widget.listenLabel),
    );
  }
}

