import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String currentPlan = 'Basic Plan';
  String name = 'John Doe';
  String email = 'john.doe@example.com';
  String phone = '(123) 456-7890';

  final List<Map<String, dynamic>> plans = [
    {'name': 'Basic Plan', 'price': 29.99, 'services': ['Wash', 'Fold', 'Iron']},
    {'name': 'Premium Plan', 'price': 49.99, 'services': ['Premium Wash', 'Fold', 'Iron', 'Stain Removal']},
    {'name': 'Premium Plus Plan', 'price': 69.99, 'services': ['Premium Wash', 'Fold', 'Iron', 'Stain Removal', 'Dry Cleaning', 'Saree Rolling', 'Shoe Cleaning']},
  ];

  final List<Map<String, String>> recentOrders = [
    {'id': '1234', 'date': '2023-05-01', 'status': 'Delivered'},
    {'id': '1233', 'date': '2023-04-28', 'status': 'Delivered'},
    {'id': '1232', 'date': '2023-04-25', 'status': 'Delivered'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
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
                  Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(email, style: TextStyle(color: Colors.grey)),
                  Text(phone, style: TextStyle(color: Colors.grey)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
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
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // Open plan selection modal
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
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
          ...recentOrders.map((order) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Order #${order['id']}', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(order['date']!, style: TextStyle(color: Colors.grey)),
              trailing: Text(order['status']!, style: TextStyle(color: Colors.black)),
            );
          }).toList(),
          SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // Navigate to full order history
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text('View All Orders', style: TextStyle(color: Colors.blue)),
                Icon(Icons.arrow_forward, color: Colors.blue),
              ],
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            // Sign Out action
          },
          child: Text('Sign Out'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ],
    );
  }
}
