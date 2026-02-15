/// True when Firebase was initialized successfully (real phone auth available).
/// Set from main.dart; read by PhoneAuth.
bool get firebaseAuthAvailable => _firebaseAuthAvailable;
bool _firebaseAuthAvailable = false;

/// Called by main.dart after successful Firebase.initializeApp().
void setFirebaseAuthAvailable(bool value) {
  _firebaseAuthAvailable = value;
}
