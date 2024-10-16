import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'LoginScreen.dart';
import '../main.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  File? _profileImage;
  String? _profilePhotoUrl;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _profileImage = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });
  }

  Future<void> _signUp() async {
    try {
      // Create user with Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Upload profile image if available
      if (_profileImage != null) {
        // Logic to upload image to Firebase Storage can go here.
        // For now, assuming profilePhotoUrl gets the link after upload.
        _profilePhotoUrl = 'uploaded_image_url';  // Replace with actual uploaded URL
      } else if (_profilePhotoUrl == null) {
        // If no Google image found, set default image from assets
        _profilePhotoUrl = 'assets/default_profile_icon.png';
      }

      // Add user information to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'profilePhotoUrl': _profilePhotoUrl ?? '', // Use either Google image, uploaded image, or default
        'role': 'user',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      // Navigate to the main screen after successful signup
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainScreen()));
    } catch (e) {
      print('Signup failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to sign up: $e'),
      ));
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        UserCredential userCredential = await _auth.signInWithCredential(credential);

        // Fetch Google profile picture
        _profilePhotoUrl = googleUser.photoUrl ?? 'assets/default_profile_icon.png';

        // Add user information to Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': googleUser.email,
          'name': googleUser.displayName ?? '',
          'phone': '', // Add later if needed
          'address': '', // Add later if needed
          'profilePhotoUrl': _profilePhotoUrl,
          'role': 'user',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        // Navigate to the main screen after successful signup
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainScreen()));
      }
    } catch (e) {
      print("Google sign in failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to sign in with Google: $e'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : AssetImage('assets/default_profile_icon.png') as ImageProvider,
                ),
              ),
              SizedBox(height: 16),

              // Email field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),

              // Password field
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),

              // Name field
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),

              // Phone field
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),

              // Address field
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),

              // Signup button
              ElevatedButton(
                onPressed: _signUp,
                child: Text('Sign Up'),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              ),
              SizedBox(height: 16),

              // Google sign-up button
              ElevatedButton.icon(
                onPressed: _signInWithGoogle,
                icon: Image.asset(
                  'assets/google_logo.png',
                  height: 24,
                  width: 24,
                ),
                label: Text('Sign up with Google'),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              ),
              SizedBox(height: 16),

              // Redirect to login button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
                },
                child: Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
