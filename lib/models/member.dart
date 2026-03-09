class Member {
  final String id;
  final String phone; // primary identifier
  final String name; // optional display name
  /// Profile photo URL (Firebase Storage). Null for pending members or when not set.
  final String? photoURL;

  Member({
    required this.id,
    required this.phone,
    this.name = '',
    this.photoURL,
  });
}
