import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Adjuntos embebidos en el documento Firestore como base64.
///
/// Presupuesto único: **1 MiB (1 048 576 caracteres)** sumando las cadenas base64
/// de todas las imágenes y el audio, como pediste; así el payload encaja mejor
/// con el límite de tamaño del documento en Firestore junto al resto de campos.
class AlertAttachmentsService {
  AlertAttachmentsService._();
  static final AlertAttachmentsService instance = AlertAttachmentsService._();

  /// Suma máxima de longitudes de strings base64 (imágenes + audio).
  static const int maxTotalBase64Chars = 1024 * 1024;

  static const int maxImages = 3;

  Future<Directory> stagingDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/alert_attachments_staging');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> stageCopy(XFile source, String prefix) async {
    final dir = await stagingDir();
    final name =
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}${_ext(source.path)}';
    final target = File('${dir.path}/$name');
    await File(source.path).copy(target.path);
    return target;
  }

  String _ext(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0) return '';
    return path.substring(i);
  }

  /// Codifica imágenes y audio respetando [maxTotalBase64Chars] en suma.
  /// Orden: fotos en orden, luego audio con el espacio restante.
  Future<PreparedAlertAttachments> prepareForFirestore(
    List<XFile> images,
    File? audioFile,
  ) async {
    final notes = <String>[];
    final imageBase64 = <String>[];
    var usedChars = 0;

    for (final f in images) {
      final bytes = await f.readAsBytes();
      if (bytes.isEmpty) continue;
      final enc = base64Encode(bytes);
      if (enc.length > maxTotalBase64Chars) {
        notes.add('Una imagen genera más de 1 MB en base64 y se omitió');
        continue;
      }
      if (usedChars + enc.length > maxTotalBase64Chars) {
        notes.add(
          'Algunas imágenes se omitieron: límite total base64 1 MB (fotos + audio)',
        );
        break;
      }
      imageBase64.add(enc);
      usedChars += enc.length;
    }

    String? audioBase64;
    if (audioFile != null && await audioFile.exists()) {
      final aBytes = await audioFile.readAsBytes();
      if (aBytes.isEmpty) {
        // nothing
      } else {
        final enc = base64Encode(aBytes);
        if (enc.length > maxTotalBase64Chars) {
          notes.add('El audio supera 1 MB en base64 y no se envió');
        } else if (usedChars + enc.length > maxTotalBase64Chars) {
          notes.add(
            'Audio omitido: no cabe junto con las fotos dentro del límite de 1 MB en base64',
          );
        } else {
          audioBase64 = enc;
          usedChars += enc.length;
        }
      }
    }

    return PreparedAlertAttachments(
      imageBase64: imageBase64,
      audioBase64: audioBase64,
      notes: notes,
      totalBase64CharsUsed: usedChars,
    );
  }
}

class PreparedAlertAttachments {
  final List<String> imageBase64;
  final String? audioBase64;
  final List<String> notes;
  final int totalBase64CharsUsed;

  const PreparedAlertAttachments({
    required this.imageBase64,
    required this.audioBase64,
    required this.notes,
    required this.totalBase64CharsUsed,
  });
}
