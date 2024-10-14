import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderTrackingScreen extends StatefulWidget {
  @override
  _OrderTrackingScreenState createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch orders from Firestore for the current logged-in user
  Future<List<Map<String, dynamic>>> fetchOrders() async {
    try {
      User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        // Reference to the user document in Firestore
        DocumentReference userRef = _firestore.collection('users').doc(currentUser.uid);

        // Fetch orders where 'userId' matches the logged-in user's reference
        QuerySnapshot snapshot = await _firestore
            .collection('orders')
            .where('userId', isEqualTo: userRef) // Query using Firestore reference
            .get();

        // Map through each document and create a list of maps with data + document ID
        return snapshot.docs.map((doc) {
          return {
            'id': doc.id, // Fetch the document ID from Firestore
            'status': doc['status'] ?? 'No status', // Handle missing or null fields
            'totalAmount': doc['totalCost'] ?? 0.0,
            'pickupDate': (doc['pickupTime'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? 'No date',
            'pickupTime': (doc['pickupTime'] as Timestamp?)?.toDate().toString().split(' ')[1] ?? 'No time',
            'expectedDeliveryDate': (doc['deliveryTime'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? 'No date',
            'expectedDeliveryTime': (doc['deliveryTime'] as Timestamp?)?.toDate().toString().split(' ')[1] ?? 'No time',
          };
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Track Orders')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No orders found.'));
          }

          final orders = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  elevation: 3,
                  margin: EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order #${order['id']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Use the Firestore document ID here
                        SizedBox(height: 8),
                        Text('Status: ${order['status']}', style: TextStyle(fontSize: 16)),
                        SizedBox(height: 8),
                        Text('Total Amount: \$${order['totalAmount'].toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Pickup: ${order['pickupDate']} at ${order['pickupTime']}', style: TextStyle(fontSize: 14)),
                        Text('Expected Delivery: ${order['expectedDeliveryDate']} at ${order['expectedDeliveryTime']}', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
