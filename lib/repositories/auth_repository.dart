class LocalUser {
  const LocalUser({
    this.uid = 'local_user',
    this.phoneNumber = '',
    this.displayName = 'Business Owner',
    this.email = '',
    this.photoURL,
  });

  final String uid;
  final String? phoneNumber;
  final String? displayName;
  final String? email;
  final String? photoURL;

  Future<void> delete() async {}
}

class AuthRepository {
  const AuthRepository();

  Stream<LocalUser?> get authStateChanges => Stream.value(const LocalUser());
  LocalUser? get currentUser => const LocalUser();

  Future<void> signOut() async {}
  Future<void> deleteAccount() async {}
}
