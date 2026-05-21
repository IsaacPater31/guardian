import 'app_logger.dart';

/// Resultado de intentar unir al usuario a las entidades oficiales configuradas.
class OfficialEntitiesEnsureResult {
  OfficialEntitiesEnsureResult({
    required this.userId,
    required this.outcomes,
    this.fatalError,
    this.fatalStackTrace,
  });

  final String? userId;
  final List<OfficialEntityJoinOutcome> outcomes;
  final Object? fatalError;
  final StackTrace? fatalStackTrace;

  bool get ok => fatalError == null;

  int get addedCount =>
      outcomes.where((o) => o.status == OfficialEntityJoinStatus.added).length;

  int get alreadyMemberCount => outcomes
      .where((o) => o.status == OfficialEntityJoinStatus.alreadyMember)
      .length;

  int get problemCount => outcomes
      .where((o) => o.status != OfficialEntityJoinStatus.added &&
          o.status != OfficialEntityJoinStatus.alreadyMember)
      .length;

  /// Escribe en consola (debug) el detalle y el resumen.
  void logToConsole() {
    const tag = '[OfficialEntities]';

    if (userId == null) {
      AppLogger.w('$tag Sin usuario autenticado — no se procesaron entidades.');
      return;
    }

    if (fatalError != null) {
      AppLogger.e('$tag Falló el proceso completo', fatalError);
      if (fatalStackTrace != null) {
        AppLogger.d('$tag Stack:\n$fatalStackTrace');
      }
    }

    AppLogger.d('$tag uid=$userId — ${outcomes.length} entidad(es) configurada(s)');

    for (final o in outcomes) {
      switch (o.status) {
        case OfficialEntityJoinStatus.added:
          AppLogger.d(
            '$tag ✓ ${o.label} (${o.communityId}): membresía creada',
          );
        case OfficialEntityJoinStatus.alreadyMember:
          AppLogger.d(
            '$tag ○ ${o.label} (${o.communityId}): ya era miembro',
          );
        case OfficialEntityJoinStatus.notFound:
          AppLogger.w(
            '$tag ✗ ${o.label} (${o.communityId}): documento no existe en Firestore',
          );
        case OfficialEntityJoinStatus.notEntity:
          AppLogger.w(
            '$tag ✗ ${o.label} (${o.communityId}): existe pero is_entity=false',
          );
        case OfficialEntityJoinStatus.invalidId:
          AppLogger.w('$tag ✗ ${o.label}: ID vacío o inválido en configuración');
        case OfficialEntityJoinStatus.perEntityError:
          AppLogger.e(
            '$tag ✗ ${o.label} (${o.communityId}): ${o.detail ?? "error"}',
            o.error,
          );
      }
    }

    if (fatalError == null) {
      AppLogger.d(
        '$tag Resumen: +$addedCount nueva(s), '
        '$alreadyMemberCount ya miembro(s), '
        '$problemCount con problema(s)',
      );
      if (addedCount > 0) {
        AppLogger.d('$tag OK — batch de membresías guardado en Firestore');
      } else if (problemCount == 0) {
        AppLogger.d('$tag OK — usuario ya pertenece a todas las entidades');
      } else if (addedCount == 0 && problemCount > 0) {
        AppLogger.w(
          '$tag Parcial/fallido — revisa IDs en default_official_entities.dart',
        );
      }
    }
  }
}

enum OfficialEntityJoinStatus {
  added,
  alreadyMember,
  notFound,
  notEntity,
  invalidId,
  perEntityError,
}

class OfficialEntityJoinOutcome {
  const OfficialEntityJoinOutcome({
    required this.label,
    required this.communityId,
    required this.status,
    this.detail,
    this.error,
  });

  final String label;
  final String communityId;
  final OfficialEntityJoinStatus status;
  final String? detail;
  final Object? error;
}
