import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'SignupScreen.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Regular Email/Password Sign In
  Future<void> _signIn() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role'];
        print('User role: $role');

        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainScreen()));
      } else {
        // If the user exists in FirebaseAuth but not in Firestore
        _showNoUserPopup();
      }
    } catch (e) {
      if (e.toString().contains("user-not-found") || e.toString().contains("wrong-password")) {
        // Handle user not found or wrong password
        _showNoUserPopup(); // Show dialog for "No account found"
      } else if (e.toString().contains("permission-denied")) {
        // Handle Firestore permission denied error
        _showNoUserPopup(); // Reuse the same popup for permission-denied
      } else {
        // Handle other errors with a general error popup
        _showErrorPopup(e);
      }
    }
  }

  // Google Sign In with email existence check
  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // The user canceled the sign-in
        return;
      }

      // Check if user email exists in Firestore users collection
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: googleUser.email)
          .get();

      if (userQuery.docs.isNotEmpty) {
        // User exists in Firestore, proceed with Google authentication
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in with Firebase
        UserCredential userCredential = await _auth.signInWithCredential(credential);

        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          // User found, proceed to main screen
          String role = userDoc['role'];
          print('User role: $role');
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => MainScreen()));
        }
      } else {
        // No user found with this email, show a popup
        _showNoUserPopup();
      }
    } catch (e) {
      if (e.toString().contains("permission-denied")) {
        // Handle Firestore permission denied error and show a dialog
        _showNoUserPopup();  // You can reuse the same popup
      } else {
        print("Google sign in failed: $e");
        _showErrorPopup(e);  // Show error popup instead of Snackbar
      }
    }
  }

  // Show a dialog informing the user that no account exists
  void _showNoUserPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('No Account Found'),
          content: Text('No account exists with these credentials. Please sign up.'),
          actions: <Widget>[
            TextButton(
              child: Text('Sign Up'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                // Navigate to SignupScreen
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SignupScreen()));
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

// Show an error popup if sign-in fails for another reason
  void _showErrorPopup(Object e) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sign-In Failed'),
          content: Text('Failed to sign in: $e'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  // Facebook Login (Functionality left blank for now)
  Future<void> _signInWithFacebook() async {
    // Functionality to be implemented later
    print("Facebook login is not implemented yet.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signIn,
              child: Text('Login'),
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50)),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _signInWithGoogle,
              icon: Image.asset(
                'assets/google_logo.png',
                height: 24,
                width: 24,
              ),
              label: Text('Sign in with Google'),
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50)),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _signInWithFacebook,
              icon: Image.asset(
                'assets/facebook_logo.png',
                height: 24,
                width: 24,
              ),
              label: Text('Sign in with Facebook'),
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50)),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => SignupScreen()));
              },
              child: Text('Don\'t have an account? Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}
