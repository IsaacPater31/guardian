/// Outcome of join / add-member flows (invite token or direct add).
///
/// Lives in [models] so handlers and services can return a stable DTO without
/// coupling UI to Firestore or auth internals.
class JoinResult {
  final bool success;
  final bool alreadyMember;
  final String? role;
  final String? message;

  JoinResult({
    required this.success,
    this.alreadyMember = false,
    this.role,
    this.message,
  });
}
