import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:guardian/core/alert_detail_catalog.dart';
import 'package:guardian/core/community_icon_catalog.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/services/alert_service.dart';
import 'package:guardian/services/alert_attachments_service.dart';
import 'package:guardian/services/audio_preview_service.dart';
import 'package:guardian/views/main_app/widgets/community_icon_picker.dart';

/// Bottom sheet para enviar un reporte a una entidad (`is_entity`).
class ReportSendSheet extends StatefulWidget {
  final String entityId;
  final String entityName;
  final int? iconCodePoint;
  final String? iconColor;
  final String? reportButtonColor;
  final List<String> allowedAlertTypes;

  const ReportSendSheet({
    super.key,
    required this.entityId,
    required this.entityName,
    this.iconCodePoint,
    this.iconColor,
    this.reportButtonColor,
    this.allowedAlertTypes = const [],
  });

  /// Muestra el sheet y devuelve `true` si el reporte se envió.
  static Future<bool?> show(
    BuildContext context, {
    required String entityId,
    required String entityName,
    int? iconCodePoint,
    String? iconColor,
    String? reportButtonColor,
    List<String> allowedAlertTypes = const [],
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportSendSheet(
        entityId: entityId,
        entityName: entityName,
        iconCodePoint: iconCodePoint,
        iconColor: iconColor,
        reportButtonColor: reportButtonColor,
        allowedAlertTypes: allowedAlertTypes,
      ),
    );
  }

  @override
  State<ReportSendSheet> createState() => _ReportSendSheetState();
}

class _ReportSendSheetState extends State<ReportSendSheet> {
  final AlertService _alertService = AlertService();
  final ImagePicker _picker = ImagePicker();
  final AlertAttachmentsService _attachments = AlertAttachmentsService.instance;
  final TextEditingController _otherController = TextEditingController();
  final FocusNode _otherFocus = FocusNode();
  final List<XFile> _pickedImages = [];
  AudioRecorder? _recorder;
  File? _audioFile;
  final Set<String> _selectedTypes = <String>{};
  final Map<String, String?> _selectedSubtypeByType = <String, String?>{};
  bool _isAnonymous = false;
  bool _isSending = false;
  bool _isRecording = false;
  int _recordElapsedSec = 0;
  Timer? _recordCapTimer;
  Timer? _recordUiTimer;
  static const String _defaultReportButtonHex = '#0D1B3E';

  Color get _accent {
    final hex = widget.reportButtonColor;
    if (hex != null && hex.isNotEmpty) {
      return CommunityIconPicker.colorFromHex(hex);
    }
    return CommunityIconPicker.colorFromHex(_defaultReportButtonHex);
  }

  IconData get _entityIcon {
    final cp = widget.iconCodePoint ?? CommunityIconCatalog.defaultIconCodePoint;
    return CommunityIconPicker.iconFromCodePoint(cp);
  }

  Color get _iconAccent {
    final hex = widget.iconColor;
    if (hex != null && hex.isNotEmpty) {
      return CommunityIconPicker.colorFromHex(hex);
    }
    return _accent;
  }

  Color get _onAccent =>
      _accent.computeLuminance() > 0.37 ? const Color(0xFF111111) : Colors.white;

  List<String> get _availableTypes {
    final all = EmergencyTypes.typeMetadata.keys.toList();
    if (widget.allowedAlertTypes.isEmpty) return all;
    final allowed = widget.allowedAlertTypes.toSet();
    return all.where(allowed.contains).toList();
  }

  bool get _requiresOtherDetail {
    for (final type in _selectedTypes) {
      final subtype = _selectedSubtypeByType[type];
      if (subtype == null) continue;
      if (AlertDetailCatalog.subtypeRequiresDetail(type, subtype)) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _recordCapTimer?.cancel();
    _recordUiTimer?.cancel();
    _recorder?.dispose();
    _otherController.dispose();
    _otherFocus.dispose();
    super.dispose();
  }

  Future<void> _stopRecording() async {
    _recordCapTimer?.cancel();
    _recordUiTimer?.cancel();
    _recordCapTimer = null;
    _recordUiTimer = null;
    final r = _recorder;
    _recorder = null;
    if (r == null) {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
      return;
    }
    try {
      final path = await r.stop();
      await r.dispose();
      if (path != null && path.isNotEmpty) {
        _audioFile = File(path);
      }
    } catch (_) {
      await r.dispose();
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordElapsedSec = 0;
    });
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    final r = AudioRecorder();
    try {
      if (!await r.hasPermission()) {
        await r.dispose();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(AppLocalizations.of(context)!.microphonePermissionSnack),
          ),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await r.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
        path: path,
      );
      _recorder = r;
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordElapsedSec = 0;
      });
      _recordUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordElapsedSec++);
      });
      _recordCapTimer = Timer(const Duration(seconds: 10), _stopRecording);
    } catch (_) {
      await r.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(AppLocalizations.of(context)!.recordingFailed),
        ),
      );
    }
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.reportSelectTypeFirst),
        ),
      );
      return;
    }
    for (final type in _selectedTypes) {
      if (_selectedSubtypeByType[type] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(l10n.selectSubtypeRequired),
          ),
        );
        return;
      }
    }
    if (_requiresOtherDetail && _otherController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.describeOtherCaseRequired),
        ),
      );
      return;
    }
    await _stopRecording();
    if (!mounted) return;
    setState(() => _isSending = true);

    final prepared = await _attachments.prepareForFirestore(_pickedImages, _audioFile);
    final notes = List<String>.from(prepared.notes);
    final customDetail = _otherController.text.trim();
    var anySent = false;
    for (final type in _selectedTypes) {
      final ok = await _alertService.sendTypedAlert(
        alertType: type,
        isAnonymous: _isAnonymous,
        communityIds: [widget.entityId],
        subtype: _selectedSubtypeByType[type],
        customDetail: customDetail.isEmpty ? null : customDetail,
        attachmentPlaceholders: notes,
        imageBase64: prepared.imageBase64.isEmpty ? null : prepared.imageBase64,
        audioBase64: prepared.audioBase64,
      );
      anySent = anySent || ok;
    }

    if (!mounted) return;
    setState(() => _isSending = false);
    Navigator.of(context).pop(anySent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final types = _availableTypes;
    final accent = _accent;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _iconAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_entityIcon, color: _iconAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.sendReportTo(widget.entityName),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  l10n.reportTypeLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (types.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    l10n.reportNoTypesConfigured,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: types.map((type) {
                      final isActive = _selectedTypes.contains(type);
                      final color = EmergencyTypes.getColor(type);
                      final icon = EmergencyTypes.getIcon(type);
                      final label =
                          EmergencyTypes.getTranslatedType(type, context);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isActive) {
                              _selectedTypes.remove(type);
                              _selectedSubtypeByType.remove(type);
                            } else {
                              _selectedTypes.add(type);
                              final options = AlertDetailCatalog.getSubtypes(type);
                              _selectedSubtypeByType[type] =
                                  options.isNotEmpty ? options.first.id : null;
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? color.withValues(alpha: 0.12)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  isActive ? color : const Color(0xFFE5E7EB),
                              width: isActive ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(icon, color: Colors.white, size: 11),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isActive
                                      ? color
                                      : const Color(0xFF374151),
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.check_circle, size: 14, color: color),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 20),
              if (_selectedTypes.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    l10n.subtypeOrReasonLabel,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                ..._selectedTypes.map((type) {
                  final options = AlertDetailCatalog.getSubtypes(type);
                  final selectedSubtype = _selectedSubtypeByType[type];
                  final color = EmergencyTypes.getColor(type);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.22)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            EmergencyTypes.getTranslatedType(type, context),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: selectedSubtype,
                            items: options
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option.id,
                                    child: Text(option.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedSubtypeByType[type] = value);
                              if (value == AlertDetailCatalog.otherSubtypeId) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (_otherFocus.canRequestFocus) {
                                    _otherFocus.requestFocus();
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
                        ],
                      ),
                    ),
                  );
                }),
                if (_requiresOtherDetail) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _otherController,
                      focusNode: _otherFocus,
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
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                      color: accent.withValues(alpha: 0.08),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.photosAndAudioSection,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.photosAndAudioPolicy(AlertAttachmentsService.maxImages),
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
                              onPressed: _pickedImages.length >= AlertAttachmentsService.maxImages
                                  ? null
                                  : () async {
                                      final x = await _picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 1400,
                                        imageQuality: 78,
                                      );
                                      if (x == null) return;
                                      setState(() {
                                        if (_pickedImages.length < AlertAttachmentsService.maxImages) {
                                          _pickedImages.add(x);
                                        }
                                      });
                                    },
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: Text(l10n.photoGallery),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickedImages.length >= AlertAttachmentsService.maxImages
                                  ? null
                                  : () async {
                                      final x = await _picker.pickImage(
                                        source: ImageSource.camera,
                                        maxWidth: 1400,
                                        imageQuality: 78,
                                      );
                                      if (x == null) return;
                                      setState(() {
                                        if (_pickedImages.length < AlertAttachmentsService.maxImages) {
                                          _pickedImages.add(x);
                                        }
                                      });
                                    },
                              icon: const Icon(Icons.photo_camera_outlined, size: 18),
                              label: Text(l10n.photoCamera),
                            ),
                          ],
                        ),
                        if (_pickedImages.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _pickedImages.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                final path = _pickedImages[i].path;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: Image.file(
                                          File(path),
                                          fit: BoxFit.cover,
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
                                          onTap: () => setState(() => _pickedImages.removeAt(i)),
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
                              _isRecording ? Icons.fiber_manual_record : Icons.mic_none_rounded,
                              color: _isRecording ? Colors.red : accent,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isRecording
                                    ? l10n.recordingProgress(_recordElapsedSec)
                                    : (_audioFile != null
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
                                onPressed: _isRecording ? _stopRecording : _startRecording,
                                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                                label: Text(
                                  _isRecording ? l10n.stopRecording : l10n.startRecording,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (_audioFile != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: TextButton(
                                  onPressed: () => setState(() => _audioFile = null),
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
                        if (_audioFile != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _LocalAudioPreview(
                              key: ValueKey(_audioFile!.path),
                              file: _audioFile!,
                              listenLabel: l10n.attachmentListenPreview,
                              pauseLabel: l10n.attachmentPausePreview,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SwitchListTile(
                  value: _isAnonymous,
                  onChanged: (v) => setState(() => _isAnonymous = v),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.reportAnonymous,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  activeTrackColor: accent,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isSending || types.isEmpty ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: _onAccent,
                      disabledBackgroundColor: accent.withValues(alpha: 0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _isSending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _onAccent,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      l10n.sendReport,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

class _LocalAudioPreview extends StatefulWidget {
  const _LocalAudioPreview({
    super.key,
    required this.file,
    required this.listenLabel,
    required this.pauseLabel,
  });

  final File file;
  final String listenLabel;
  final String pauseLabel;

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
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(AppLocalizations.of(context)!.audioPreviewFailed),
          ),
        );
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
