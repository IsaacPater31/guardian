import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/services/alert_service.dart';

/// Bottom sheet para enviar un reporte a una entidad (`is_entity`).
///
/// Un reporte es una alerta normal (misma colección y tipos) cuyo destino es
/// exclusivamente la entidad: nunca se mezcla con comunidades normales.
/// Solo los miembros `official`/`admin` de la entidad reciben la notificación.
class ReportSendSheet extends StatefulWidget {
  final String entityId;
  final String entityName;

  const ReportSendSheet({
    super.key,
    required this.entityId,
    required this.entityName,
  });

  /// Muestra el sheet y devuelve `true` si el reporte se envió.
  static Future<bool?> show(
    BuildContext context, {
    required String entityId,
    required String entityName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportSendSheet(
        entityId: entityId,
        entityName: entityName,
      ),
    );
  }

  @override
  State<ReportSendSheet> createState() => _ReportSendSheetState();
}

class _ReportSendSheetState extends State<ReportSendSheet> {
  final AlertService _alertService = AlertService();
  final TextEditingController _detailController = TextEditingController();
  String? _selectedType;
  bool _isAnonymous = false;
  bool _isSending = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.reportSelectTypeFirst),
        ),
      );
      return;
    }
    setState(() => _isSending = true);

    final detail = _detailController.text.trim();
    final ok = await _alertService.sendTypedAlert(
      alertType: _selectedType!,
      isAnonymous: _isAnonymous,
      // Destino exclusivo: la entidad. No se mezcla con comunidades normales.
      communityIds: [widget.entityId],
      customDetail: detail.isEmpty ? null : detail,
    );

    if (!mounted) return;
    setState(() => _isSending = false);
    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final types = EmergencyTypes.typeMetadata.keys.toList();

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

              // Título
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B3E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.assignment_rounded,
                        color: Color(0xFF0D1B3E),
                        size: 20,
                      ),
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

              // Tipo de reporte
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: types.map((type) {
                    final isActive = _selectedType == type;
                    final color = EmergencyTypes.getColor(type);
                    final icon = EmergencyTypes.getIcon(type);
                    final label =
                        EmergencyTypes.getTranslatedType(type, context);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
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
                              child:
                                  Icon(icon, color: Colors.white, size: 11),
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
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Detalle opcional
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: TextField(
                    controller: _detailController,
                    maxLines: 3,
                    maxLength: 200,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: l10n.reportDetailHint,
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Anónimo
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
                  activeTrackColor: const Color(0xFF0D1B3E),
                ),
              ),
              const SizedBox(height: 8),

              // Enviar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D1B3E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
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
