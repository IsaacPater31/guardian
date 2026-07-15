/// Ephemeral "you were added to a community" signal (before UI consumes it).
class MemberAddedWelcomeSignal {
  const MemberAddedWelcomeSignal({
    required this.id,
    required this.communityId,
    required this.communityName,
  });

  final String id;
  final String communityId;

  /// Display name; falls back to [communityId] when the signal has no name.
  final String communityName;

  String get displayName =>
      communityName.trim().isNotEmpty ? communityName.trim() : communityId;
}
