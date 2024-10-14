import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'LoginScreen.dart';
import 'OrderTracking.dart'; // Import the Orders page

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String currentPlan = 'Basic Plan'; // Can be dynamically set based on user data
  String name = '';
  String email = '';
  String phone = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> recentOrders = [];

  final List<Map<String, dynamic>> plans = [
    {'name': 'Basic Plan', 'price': 29.99, 'services': ['Wash', 'Fold', 'Iron']},
    {'name': 'Premium Plan', 'price': 49.99, 'services': ['Premium Wash', 'Fold', 'Iron', 'Stain Removal']},
    {'name': 'Premium Plus Plan', 'price': 69.99, 'services': ['Premium Wash', 'Fold', 'Iron', 'Stain Removal', 'Dry Cleaning', 'Saree Rolling', 'Shoe Cleaning']},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchUserOrders();
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
              'date': (doc['createdAt'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? 'N/A',
              'status': doc['status'] ?? 'Unknown',
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching recent orders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildProfileSection(),
            SizedBox(height: 16),
            buildSubscriptionSection(),
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
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage('https://via.placeholder.com/100'),
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
          ElevatedButton(
            onPressed: () {
              // Change Profile Picture Action
            },
            child: Text('Change Profile Picture'),
          ),
          SizedBox(height: 16),
          buildTextField('Name', name, (value) {
            setState(() {
              name = value;
            });
          }),
          buildTextField('Email', email, (value) {
            setState(() {
              email = value;
            });
          }),
          buildTextField('Phone', phone, (value) {
            setState(() {
              phone = value;
            });
          }),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Save Changes Action
            },
            child: Text('Save Changes'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(String label, String value, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          TextField(
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: value,
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
          Text('Current Plan: $currentPlan', style: TextStyle(fontSize: 16)),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Open plan selection modal
            },
            child: Text('Change Plan'),
          ),
        ],
      ),
    );
  }

  Widget buildRecentOrdersSection() {
    return Container(
      padding: EdgeInsets.all(16.0),
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
              // Navigate to Order History page
              Navigator.push(context, MaterialPageRoute(builder: (context) => OrderTrackingScreen()));
            },
            child: Text('View All Orders'),
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: _signOut,
          child: Text('Sign Out'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Sign out error: $e');
    }
  }
}
