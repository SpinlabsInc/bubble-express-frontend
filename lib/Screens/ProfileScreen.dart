import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'LoginScreen.dart';
import 'OrderTracking.dart';
import 'SubscriptionScreen.dart';  // Import SubscriptionScreen
import 'package:google_fonts/google_fonts.dart'; // Import google_fonts

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? currentPlan;
  String name = '';
  String email = '';
  String phone = '';
  String profileImageUrl = '';
  File? _image;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final FocusNode nameFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode phoneFocusNode = FocusNode();

  List<Map<String, dynamic>> recentOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchUserOrders();
    _fetchCurrentPlan();  // Fetch subscription plan
  }

  Future<void> _fetchUserProfile() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            name = userDoc['name'] ?? 'N/A';
            email = userDoc['email'] ?? 'N/A';
            phone = userDoc['phone'] ?? 'N/A';
            profileImageUrl = userDoc['profilePhotoUrl'] ?? '';
            nameController.text = name;
            emailController.text = email;
            phoneController.text = phone;
          });
        }
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  Future<void> _fetchUserOrders() async {
    try {
      User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

        QuerySnapshot ordersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: userRef)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get();

        setState(() {
          recentOrders = ordersSnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'date': (doc['createdAt'] as Timestamp?)?.toDate().toLocal().toString().split(' ')[0] ?? 'N/A',
              'status': doc['status'] ?? 'Unknown',
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching orders: $e');
    }
  }

  Future<void> _fetchCurrentPlan() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('subscriptions')
            .where('userId', isEqualTo: FirebaseFirestore.instance.collection('users').doc(currentUser.uid))
            .orderBy('startDate', descending: true)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          var subscription = snapshot.docs.first;

          // Fetch the plan reference from the 'services' field
          DocumentReference planRef = subscription['services'] as DocumentReference;

          // Ensure the plan reference is valid before fetching the plan details
          DocumentSnapshot planSnapshot = await planRef.get();

          if (planSnapshot.exists) {
            setState(() {
              currentPlan = planSnapshot['name'];  // Update current plan from Firestore
            });
          } else {
            print('Plan not found');
          }
        } else {
          print('No subscription found for the user');
        }
      } catch (e) {
        print('Error fetching current plan: $e');
      }
    }
  }

  Future<void> _updateProfileImage(File imageFile) async {
    try {
      User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        final storageRef = FirebaseStorage.instance.ref().child('profileImages/${currentUser.uid}');
        final uploadTask = await storageRef.putFile(imageFile);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
          'profilePhotoUrl': downloadUrl,
        });

        setState(() {
          profileImageUrl = downloadUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile picture updated successfully')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile picture')));
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _updateProfileImage(_image!);
    }
  }

  Future<void> _updateUserProfile() async {
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
          'name': nameController.text,
          'email': emailController.text,
          'phone': phoneController.text,
        });

        await currentUser.updateEmail(emailController.text);

        setState(() {
          name = nameController.text;
          email = emailController.text;
          phone = phoneController.text;
        });

        nameFocusNode.unfocus();
        emailFocusNode.unfocus();
        phoneFocusNode.unfocus();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated successfully')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to sign out')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildProfileSection(),
            SizedBox(height: 16),
            buildSubscriptionSection(), // Subscription section
            SizedBox(height: 16),
            buildRecentOrdersSection(),
            SizedBox(height: 16),
            buildSupportAndSignOutButtons(),
          ],
        ),
      ),
    );
  }

  Widget buildProfileSection() {
    return Container(
      padding: EdgeInsets.all(16.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: profileImageUrl.isEmpty
                        ? NetworkImage('https://via.placeholder.com/100')
                        : NetworkImage(profileImageUrl),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.edit, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Loading...' : name,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(email.isEmpty ? 'Loading...' : email, style: TextStyle(color: Colors.grey)),
                  Text(phone.isEmpty ? 'Loading...' : phone, style: TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          buildTextField('Name', nameController, nameFocusNode),
          buildTextField('Email', emailController, emailFocusNode),
          buildTextField('Phone', phoneController, phoneFocusNode),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _updateUserProfile,
            child: Text('Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(String label, TextEditingController controller, FocusNode focusNode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSubscriptionSection() {
    return Container(
      padding: EdgeInsets.all(16.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subscription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            currentPlan != null
                ? 'Current Plan: $currentPlan'
                : 'No current plan found.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Navigate to SubscriptionScreen when "Change Plan" is clicked
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SubscriptionScreen()),
              );
            },
            child: Text('Change Plan'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRecentOrdersSection() {
    return Container(
      padding: EdgeInsets.all(16.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          if (recentOrders.isEmpty)
            Text('No recent orders found.', style: TextStyle(color: Colors.grey))
          else
            ...recentOrders.map((order) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Order #${order['id']}', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(order['date'] ?? 'N/A', style: TextStyle(color: Colors.grey)),
                trailing: Text(order['status'] ?? 'Unknown', style: TextStyle(color: Colors.black)),
              );
            }).toList(),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => OrderTrackingScreen()));
            },
            child: Text('View All Orders'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSupportAndSignOutButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            // Support action
          },
          child: Text('Support'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            minimumSize: Size(double.infinity, 50),
          ),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: _signOut,
          child: Text('Sign Out'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            minimumSize: Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }
}
