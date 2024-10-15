import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'SignupScreen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _signIn() async {
    try {
      // Sign in with email and password
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Fetch user data from Firestore
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();

      if (userDoc.exists) {
        String role = userDoc['role'];
        print('User role: $role');

        // Navigate to the main screen after successful login
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainScreen()));
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

  Future<void> _sendResetPasswordEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Password reset link sent to $email'),
      ));
    } catch (e) {
      print('Failed to send reset password email: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to send reset password email: $e'),
      ));
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController _forgotPasswordEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _forgotPasswordEmailController,
                decoration: InputDecoration(
                  labelText: 'Enter your email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                String email = _forgotPasswordEmailController.text.trim();
                if (email.isNotEmpty) {
                  _sendResetPasswordEmail(email);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Please enter your email'),
                  ));
                }
              },
              child: Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }

  void _showUpdatePasswordDialog(BuildContext context, User user) {
    final TextEditingController _newPasswordController = TextEditingController();
    final TextEditingController _confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'Enter new password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String newPassword = _newPasswordController.text.trim();
                String confirmPassword = _confirmPasswordController.text.trim();

                if (newPassword == confirmPassword && newPassword.isNotEmpty) {
                  try {
                    await user.updatePassword(newPassword);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Password updated successfully'),
                    ));
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Password update failed: $e'),
                    ));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Passwords do not match or are empty'),
                  ));
                }
              },
              child: Text('Update Password'),
            ),
          ],
        );
      },
    );
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
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _showForgotPasswordDialog(context);
              },
              child: Text('Forgot Password?'),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Navigate to sign-up screen
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SignupScreen()));
              },
              child: Text('Don\'t have an account? Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}
