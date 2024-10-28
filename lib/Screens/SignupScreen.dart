import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Firebase Storage
import 'LoginScreen.dart';
import '../main.dart';

class SignupScreen extends StatefulWidget {
  final GoogleSignInAccount? googleUser;

  SignupScreen({this.googleUser});

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

  @override
  void initState() {
    super.initState();

    if (widget.googleUser != null) {
      _emailController.text = widget.googleUser!.email;
      _nameController.text = widget.googleUser!.displayName ?? '';
      _profilePhotoUrl = widget.googleUser!.photoUrl ?? 'assets/default_profile_icon.png';
    }
  }

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

  Future<String?> _uploadProfileImage(User user) async {
    try {
      if (_profileImage == null) return null;

      Reference storageReference = FirebaseStorage.instance.ref().child('profile_images/${user.uid}.jpg');
      UploadTask uploadTask = storageReference.putFile(_profileImage!);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  // Method to handle Google Sign-Up
  Future<void> _signUpWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      try {
        // Check if user already exists in Firestore
        QuerySnapshot userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: googleUser.email)
            .get();

        if (userQuery.docs.isNotEmpty) {
          // User already exists, show popup
          _showAccountExistsPopup();
        } else {
          // Add user information to Firestore
          _profilePhotoUrl = googleUser.photoUrl ?? 'assets/default_profile_icon.png';
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'email': googleUser.email,
            'name': googleUser.displayName ?? '',
            'profilePhotoUrl': _profilePhotoUrl,
            'role': 'user',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });

          // Show popup to complete profile
          _showAddressAndPhonePopup(userCredential.user!);
        }
      } catch (e) {
        if (e.toString().contains("PERMISSION_DENIED")) {
          _showAccountExistsPopup();
        } else {
          print("Error: $e");
        }
      }
    } catch (e) {
      print("Google sign in failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to sign up with Google: $e'),
      ));
    }
  }

  // Show popup to inform user that the account already exists
  void _showAccountExistsPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Account Already Exists'),
          content: Text('An account with this email already exists. Please log in instead.'),
          actions: <Widget>[
            TextButton(
              child: Text('Log In'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
              },
            ),
          ],
        );
      },
    );
  }

  // Show popup to collect phone and address and update Firestore
  void _showAddressAndPhonePopup(User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Complete your profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Submit'),
              onPressed: () async {
                // Update Firestore with the new phone and address
                await _firestore.collection('users').doc(user.uid).update({
                  'phone': _phoneController.text.trim(),
                  'address': _addressController.text.trim(),
                  'updatedAt': Timestamp.now(),
                });

                // Close the dialog and proceed to the main screen
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => MainScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Method to handle Email/Password Sign-Up
  Future<void> _signUp() async {
    try {
      // Check if the email already exists in Firebase Authentication
      List<String> signInMethods = await _auth.fetchSignInMethodsForEmail(_emailController.text.trim());

      if (signInMethods.isNotEmpty) {
        // Email already exists, show the popup instead of Snackbar
        _showAccountExistsPopup();
      } else {
        // Proceed with creating a new user
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        String? profileImageUrl = await _uploadProfileImage(userCredential.user!);

        _profilePhotoUrl = profileImageUrl ?? 'assets/default_profile_icon.png';

        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'profilePhotoUrl': _profilePhotoUrl ?? '',
          'role': 'user',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainScreen()));
      }
    } catch (e) {
      if (e.toString().contains('email-already-in-use')) {
        // Handle the "email already in use" error by showing the popup
        _showAccountExistsPopup();
      } else {
        // You can handle other errors here (if needed)
        print('Signup failed: $e');
      }
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
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              // Sign up button for email/password
              ElevatedButton(
                onPressed: _signUp,
                child: Text('Sign Up'),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              ),
              SizedBox(height: 16),
              // Google sign-up button with logo
              ElevatedButton.icon(
                onPressed: _signUpWithGoogle,
                icon: Image.asset(
                  'assets/google_logo.png',
                  height: 24,
                  width: 24,
                ),
                label: Text('Sign up with Google'),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              ),
              SizedBox(height: 16),
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
