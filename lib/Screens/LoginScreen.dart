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
        print('No user data found');
      }
    } catch (e) {
      print("Sign in failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to sign in: $e'),
      ));
    }
  }

  // Google Sign In
  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        QuerySnapshot userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: googleUser.email)
            .get();

        if (userQuery.docs.isNotEmpty) {
          UserCredential userCredential =
          await _auth.signInWithCredential(credential);

          DocumentSnapshot userDoc = await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

          if (userDoc.exists) {
            String role = userDoc['role'];
            print('User role: $role');

            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => MainScreen()));
          }
        } else {
          print('No user account found for this email');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
            Text('No account found for this email. Please sign up first.'),
          ));

          await _auth.signOut();
          await _googleSignIn.disconnect();
        }
      }
    } catch (e) {
      print("Google sign in failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to sign in with Google: $e'),
      ));
    }
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
