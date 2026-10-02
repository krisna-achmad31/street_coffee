import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/admin_config.dart';
import '../../core/utils/failures.dart';
import '../../domain/entities/app_user.dart';

abstract class AuthRemoteDataSource {
  Stream<AppUser?> get authStateChanges;
  Future<AppUser> signInWithGoogle();
  Future<void> signOut();
  AppUser? get currentUser;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRemoteDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn;

  @override
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_mapFirebaseUser);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    // signInWithProvider buka browser — normal di Android
    // Firebase auth state stream akan otomatis update setelah browser redirect
    final googleProvider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');

    try {
      final userCredential = await _firebaseAuth.signInWithProvider(
        googleProvider,
      );
      final user = userCredential.user;
      if (user == null) throw const ServerFailure('Gagal masuk. Coba lagi.');
      return _mapFirebaseUser(user)!;
    } on FirebaseAuthException catch (e) {
      // Kalau user tutup browser sebelum selesai
      if (e.code == 'web-context-canceled') {
        throw const ServerFailure('Login dibatalkan');
      }
      // Cek apakah sudah login via auth state (redirect sudah selesai)
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) return _mapFirebaseUser(currentUser)!;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut().catchError((_) {}),
    ]);
  }

  @override
  AppUser? get currentUser => _mapFirebaseUser(_firebaseAuth.currentUser);

  AppUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: (user.displayName ?? '').trim().isEmpty
          ? (user.email?.split('@').first ?? 'Pengopi')
          : user.displayName!.trim(),
      photoUrl: user.photoURL,
      isAdmin: AdminConfig.isAdmin(user.uid),
    );
  }
}