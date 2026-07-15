import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:guardian/shared/catalog/community_icon_catalog.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/features/entity_reports/domain/entity_report_type.dart';
import 'package:guardian/features/alerts/application/alert_service.dart';
import 'package:guardian/features/alerts/application/alert_attachments_service.dart';
import 'package:guardian/features/alerts/application/audio_preview_service.dart';
import 'package:guardian/features/communities/presentation/widgets/community_icon_picker.dart';

/// Fullscreen report flow: type + detail + send in a single step
/// (same mental model as community alert confirmation).
class ReportSendSheet {
  ReportSendSheet._();

  /// Opens the flow and returns `true` if a report was sent.
  static Future<bool?> show(
    BuildContext context, {
    required String entityId,
    required String entityName,
    int? iconCodePoint,
    String? iconColor,
    String? reportButtonColor,
    List<EntityReportType> allowedAlertTypes = const [],
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReportComposePage(
          entityId: entityId,
          entityName: entityName,
          iconCodePoint: iconCodePoint,
          iconColor: iconColor,
          reportButtonColor: reportButtonColor,
          allowedTypes: allowedAlertTypes,
        ),
      ),
    );
  }
}

class ReportComposePage extends StatefulWidget {
  const ReportComposePage({
    super.key,
    required this.entityId,
    required this.entityName,
    required this.allowedTypes,
    this.iconCodePoint,
    this.iconColor,
    this.reportButtonColor,
  });

  final String entityId;
  final String entityName;
  final List<EntityReportType> allowedTypes;
  final int? iconCodePoint;
  final String? iconColor;
  final String? reportButtonColor;

  @override
  State<ReportComposePage> createState() => _ReportComposePageState();
}

class _ReportComposePageState extends State<ReportComposePage> {
  final AlertService _alertService = AlertService();
  final ImagePicker _picker = ImagePicker();
  final AlertAttachmentsService _attachments = AlertAttachmentsService.instance;
  final TextEditingController _detailController = TextEditingController();
  final List<XFile> _pickedImages = [];
  AudioRecorder? _recorder;
  File? _audioFile;
  EntityReportType? _selectedType;
  bool _isAnonymous = false;
  bool _isSending = false;
  bool _isRecording = false;
  int _recordElapsedSec = 0;
  Timer? _recordCapTimer;
  Timer? _recordUiTimer;

  Color get _entityAccent {
    final hex = widget.reportButtonColor;
    if (hex != null && hex.isNotEmpty) {
      return CommunityIconPicker.colorFromHex(hex);
    }
    return CommunityIconPicker.colorFromHex('#0D1B3E');
  }

  Color get _accent {
    final selected = _selectedType;
    if (selected != null) {
      return CommunityIconPicker.colorFromHex(selected.color);
    }
    return _entityAccent;
  }

  Color get _onAccent =>
      _accent.computeLuminance() > 0.37 ? const Color(0xFF111111) : Colors.white;

  @override
  void initState() {
    super.initState();
    if (widget.allowedTypes.isNotEmpty) {
      _selectedType = widget.allowedTypes.first;
    }
  }

  @override
  void dispose() {
    _recordCapTimer?.cancel();
    _recordUiTimer?.cancel();
    _recorder?.dispose();
    _detailController.dispose();
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
      if (mounted) setState(() => _isRecording = false);
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
      final path =
          '${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
    final type = _selectedType;
    if (type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.reportTypeLabel),
        ),
      );
      return;
    }

    await _stopRecording();
    if (!mounted) return;
    setState(() => _isSending = true);

    final prepared =
        await _attachments.prepareForFirestore(_pickedImages, _audioFile);
    final detail = _detailController.text.trim();
    final ok = await _alertService.sendTypedAlert(
      alertType: type.id,
      alertTypeLabel: type.name,
      alertTypeColor: type.color,
      alertTypeIconCodePoint: type.iconCodePoint,
      isAnonymous: _isAnonymous,
      communityIds: [widget.entityId],
      customDetail: detail.isEmpty ? null : detail,
      attachmentPlaceholders: List<String>.from(prepared.notes),
      imageBase64: prepared.imageBase64.isEmpty ? null : prepared.imageBase64,
      audioBase64: prepared.audioBase64,
    );

    if (!mounted) return;
    setState(() => _isSending = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.reportSentError),
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  Widget _buildTypePicker(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.reportTypeLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedType?.id,
          isExpanded: true,
          items: widget.allowedTypes
              .map(
                (type) => DropdownMenuItem<String>(
                  value: type.id,
                  child: Row(
                    children: [
                      Icon(
                        CommunityIconPicker.iconFromCodePoint(
                          type.iconCodePoint,
                        ),
                        size: 18,
                        color: CommunityIconPicker.colorFromHex(type.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          type.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            EntityReportType? match;
            for (final t in widget.allowedTypes) {
              if (t.id == value) {
                match = t;
                break;
              }
            }
            if (match == null) return;
            setState(() => _selectedType = match);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entityIcon = CommunityIconPicker.iconFromCodePoint(
      widget.iconCodePoint ?? CommunityIconCatalog.defaultIconCodePoint,
    );
    final iconAccent =
        (widget.iconColor != null && widget.iconColor!.isNotEmpty)
            ? CommunityIconPicker.colorFromHex(widget.iconColor!)
            : _entityAccent;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(l10n.sendReportTo(widget.entityName)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
      ),
      body: widget.allowedTypes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.reportNoTypesConfigured,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 15),
                ),
              ),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: iconAccent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: iconAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(entityIcon, color: iconAccent, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.sendReportTo(widget.entityName),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTypePicker(l10n),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _detailController,
                    minLines: 2,
                    maxLines: 4,
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
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.35),
                      ),
                      color: _accent.withValues(alpha: 0.08),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.photosAndAudioSection,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _accent,
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
                              onPressed: _pickedImages.length >=
                                      AlertAttachmentsService.maxImages
                                  ? null
                                  : () async {
                                      final x = await _picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 1400,
                                        imageQuality: 78,
                                      );
                                      if (x == null) return;
                                      setState(() {
                                        if (_pickedImages.length <
                                            AlertAttachmentsService.maxImages) {
                                          _pickedImages.add(x);
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
                              onPressed: _pickedImages.length >=
                                      AlertAttachmentsService.maxImages
                                  ? null
                                  : () async {
                                      final x = await _picker.pickImage(
                                        source: ImageSource.camera,
                                        maxWidth: 1400,
                                        imageQuality: 78,
                                      );
                                      if (x == null) return;
                                      setState(() {
                                        if (_pickedImages.length <
                                            AlertAttachmentsService.maxImages) {
                                          _pickedImages.add(x);
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
                        if (_pickedImages.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _pickedImages.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: Image.file(
                                          File(_pickedImages[i].path),
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
                                        child: InkWell(
                                          onTap: () => setState(
                                            () => _pickedImages.removeAt(i),
                                          ),
                                          customBorder: const CircleBorder(),
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
                              _isRecording
                                  ? Icons.fiber_manual_record
                                  : Icons.mic_none_rounded,
                              color: _isRecording ? Colors.red : _accent,
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
                                onPressed: _isRecording
                                    ? _stopRecording
                                    : _startRecording,
                                icon: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                ),
                                label: Text(
                                  _isRecording
                                      ? l10n.stopRecording
                                      : l10n.startRecording,
                                ),
                              ),
                            ),
                            if (_audioFile != null) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _audioFile = null),
                                child: Text(l10n.removeAudio),
                              ),
                            ],
                          ],
                        ),
                        if (_audioFile != null) ...[
                          const SizedBox(height: 8),
                          _LocalAudioPreview(
                            key: ValueKey(_audioFile!.path),
                            file: _audioFile!,
                            listenLabel: l10n.attachmentListenPreview,
                            pauseLabel: l10n.attachmentPausePreview,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
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
                    activeTrackColor: _accent,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSending || _selectedType == null
                          ? null
                          : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: _onAccent,
                        disabledBackgroundColor:
                            _accent.withValues(alpha: 0.4),
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
                      ),
                    ),
                  ),
                ],
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
