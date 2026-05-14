import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _saveUserToFirestore(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ?? user.email ?? 'Utilisateur',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null) {
      await _saveUserToFirestore(credential.user!);
    }

    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null) {
      await _saveUserToFirestore(credential.user!);
    }

    return credential;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential? credential;

      if (kIsWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        credential = await _auth.signInWithProvider(GoogleAuthProvider());
      }

      if (credential.user != null) {
        await _saveUserToFirestore(credential.user!);
      }

      return credential;
    } catch (e) {
      print('Erreur Google: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithFacebook() async {
    try {
      UserCredential? credential;

      if (kIsWeb) {
        credential = await _auth.signInWithPopup(FacebookAuthProvider());
      } else {
        final result = await FacebookAuth.instance.login();

        if (result.status == LoginStatus.success) {
          final authCredential = FacebookAuthProvider.credential(
            result.accessToken!.token,
          );
          credential = await _auth.signInWithCredential(authCredential);
        } else {
          credential = await _auth.signInWithProvider(FacebookAuthProvider());
        }
      }

      if (credential?.user != null) {
        await _saveUserToFirestore(credential!.user!);
      }

      return credential;
    } catch (e) {
      print('Erreur Facebook: $e');

      try {
        final credential = await _auth.signInWithProvider(
          FacebookAuthProvider(),
        );

        if (credential.user != null) {
          await _saveUserToFirestore(credential.user!);
        }

        return credential;
      } catch (_) {
        rethrow;
      }
    }
  }

  Future<UserCredential?> signInWithGitHub() async {
    try {
      final githubProvider = GithubAuthProvider();

      final credential = kIsWeb
          ? await _auth.signInWithPopup(githubProvider)
          : await _auth.signInWithProvider(githubProvider);

      if (credential.user != null) {
        await _saveUserToFirestore(credential.user!);
      }

      return credential;
    } catch (e) {
      print('Erreur GitHub: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        try {
          await FacebookAuth.instance.logOut();
        } catch (_) {}
      }

      await _auth.signOut();
    } catch (e) {
      print('Erreur SignOut: $e');
    }
  }
}