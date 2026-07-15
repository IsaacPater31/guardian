/// Lightweight user directory hit for "add member" search.
class UserSearchHit {
  const UserSearchHit({
    required this.uid,
    required this.name,
    required this.email,
  });

  final String uid;
  final String name;
  final String email;
}
