// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:flutter/foundation.dart';

// class GoogleSignInService {
//   static final GoogleSignInService _instance = GoogleSignInService._internal();
//   factory GoogleSignInService() => _instance;
//   GoogleSignInService._internal();

//   // Initialize Google Sign-In
//   final GoogleSignIn _googleSignIn = GoogleSignIn(
//     scopes: ['email', 'profile'],
//     // Add your OAuth client ID here (optional for web, required for mobile)
//     // Get it from: https://console.cloud.google.com/apis/credentials
//     // clientId: 'YOUR_CLIENT_ID.apps.googleusercontent.com',
//   );

//   /// Sign in with Google
//   Future<Map<String, dynamic>> signIn() async {
//     try {
//       // Start sign-in flow
//       final GoogleSignInAccount? account = await _googleSignIn.signIn();

//       if (account == null) {
//         // User cancelled
//         return {
//           'success': false,
//           'message': 'Sign-in cancelled',
//         };
//       }

//       // Get authentication tokens
//       final GoogleSignInAuthentication auth = await account.authentication;
//       final String? idToken = auth.idToken;

//       if (idToken == null) {
//         return {
//           'success': false,
//           'message': 'Failed to get ID token',
//         };
//       }

//       return {
//         'success': true,
//         'idToken': idToken,
//         'email': account.email,
//         'displayName': account.displayName,
//         'photoUrl': account.photoUrl,
//       };
//     } catch (e) {
//       if (kDebugMode) {
//         print('Google Sign-In Error: $e');
//       }
//       return {
//         'success': false,
//         'message': 'Google sign-in failed: ${e.toString()}',
//       };
//     }
//   }

//   /// Sign out
//   Future<void> signOut() async {
//     try {
//       await _googleSignIn.signOut();
//     } catch (e) {
//       if (kDebugMode) {
//         print('Google Sign-Out Error: $e');
//       }
//     }
//   }

//   /// Check if user is signed in
//   Future<bool> isSignedIn() async {
//     return await _googleSignIn.isSignedIn();
//   }
// }
