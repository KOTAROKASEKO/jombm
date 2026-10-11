import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  static bool _googleReady = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      await credential.user?.updateDisplayName(trimmedName);
    }
  }

  Future<void> signInWithGoogle() async {
    await _ensureGoogleReady();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Google ID token was not returned.',
      );
    }
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }
}

String authErrorMessage(Object error) {
  if (error is GoogleSignInException) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return '';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Googleサインインの設定がまだ完了していません。';
      default:
        return error.description ?? 'Googleサインインに失敗しました。';
    }
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'user-disabled':
        return 'このアカウントは無効です。';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'メールアドレスまたはパスワードが正しくありません。';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使われています。';
      case 'weak-password':
        return 'パスワードは6文字以上にしてください。';
      case 'operation-not-allowed':
        return 'このサインイン方法はまだ有効になっていません。';
      case 'network-request-failed':
        return 'ネットワークエラーです。接続を確認してください。';
      case 'too-many-requests':
        return 'しばらく時間をおいてから再試行してください。';
      default:
        return error.message ?? '認証に失敗しました。';
    }
  }

  return '認証に失敗しました。';
}
