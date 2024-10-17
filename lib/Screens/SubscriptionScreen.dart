import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import for date formatting and difference calculation

class SubscriptionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscriptions'),
      ),
      body: FutureBuilder<List<SubscriptionRecord>>(
        future: fetchSubscriptions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('An error occurred: ${snapshot.error}'));
          }

          final subscriptions = snapshot.data ?? [];

          if (subscriptions.isEmpty) {
            return Center(
              child: Text(
                'No Subscriptions found',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              final subscription = subscriptions[index];
              return SubscriptionCard(subscription: subscription);
            },
          );
        },
      ),
    );
  }

  Future<List<SubscriptionRecord>> fetchSubscriptions() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;

    if (user == null) {
      throw Exception('No user is logged in.');
    }

    final String userId = user.uid;

    DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('userId', isEqualTo: userDocRef)
          .get();

      return querySnapshot.docs.map((doc) {
        return SubscriptionRecord.fromSnapshot(doc);
      }).toList();
    } catch (e) {
      throw e;
    }
  }
}

class SubscriptionCard extends StatefulWidget {
  final SubscriptionRecord subscription;

  const SubscriptionCard({required this.subscription});

  @override
  _SubscriptionCardState createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  late bool isActive;
  bool hideButtons = false; // Track if buttons should be hidden
  String serviceName = 'Loading...'; // Variable to hold the service name

  @override
  void initState() {
    super.initState();
    isActive = widget.subscription.isActive;
    _fetchServiceName(); // Fetch the service name on initialization
  }

  // Fetch the service name from the 'plans' collection using the service reference
  Future<void> _fetchServiceName() async {
    if (widget.subscription.services != null) {
      try {
        DocumentSnapshot serviceDoc = await widget.subscription.services!.get();
        if (serviceDoc.exists) {
          setState(() {
            serviceName = serviceDoc['name'] ?? 'Unknown Service';
          });
        } else {
          setState(() {
            serviceName = 'Service not found';
          });
        }
      } catch (e) {
        setState(() {
          serviceName = 'Error fetching service';
        });
      }
    } else {
      setState(() {
        serviceName = 'No Service Available';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceType = widget.subscription.serviceType ?? 'N/A';
    final amount = widget.subscription.paymentDetails['amount'] ?? 'N/A';
    final transactionId = widget.subscription.paymentDetails['transactionId'] ?? 'N/A';
    final startDate = widget.subscription.startDate?.toDate().toLocal().toString().split(' ')[0] ?? 'N/A';
    final endDate = widget.subscription.endDate?.toDate().toLocal().toString().split(' ')[0] ?? 'N/A';

    // Calculate remaining days based on startDate and endDate
    final DateTime? startDateObject = widget.subscription.startDate?.toDate();
    final DateTime? endDateObject = widget.subscription.endDate?.toDate();

    int remainingDays = 0;
    if (startDateObject != null && endDateObject != null) {
      remainingDays = endDateObject.difference(startDateObject).inDays + 1;  // Include both start and end days
    }

    // Ensure that remaining days never show a negative value
    final remainingDaysText = remainingDays >= 0 ? '$remainingDays days' : 'Subscription Ended';

    final statusText = isActive ? 'Active' : 'Inactive';
    final statusColor = isActive ? Colors.green : Colors.red;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service Name: $serviceName', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Service Type: $serviceType', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Amount: ₹$amount', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Transaction ID: $transactionId', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Start Date: $startDate', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('End Date: $endDate', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text(
              'Remaining Days: $remainingDaysText',
              style: TextStyle(fontSize: 16, color: Colors.blue),
            ),
            SizedBox(height: 8),
            Text(
              'Status: $statusText',
              style: TextStyle(fontSize: 16, color: statusColor),
            ),
            SizedBox(height: 16),
            if (!hideButtons) // Buttons are hidden only after cancellation
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isActive
                          ? () => _updateSubscriptionStatus(context, widget.subscription.reference, false)
                          : () => _updateSubscriptionStatus(context, widget.subscription.reference, true),
                      child: Text(isActive ? 'Pause' : 'Resume'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? Colors.orange : Colors.green,
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmCancellation(context),
                      child: Text('Cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateSubscriptionStatus(BuildContext context, DocumentReference subscriptionRef, bool newStatus) async {
    try {
      await subscriptionRef.update({'isActive': newStatus});
      setState(() {
        isActive = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus ? 'Subscription Resumed' : 'Subscription Paused')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating subscription')),
      );
    }
  }

  Future<void> _confirmCancellation(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Cancellation'),
          content: Text('Are you sure you want to cancel this subscription? This action is irreversible.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss dialog
              },
              child: Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss dialog
                _cancelSubscription(context, widget.subscription.reference);
              },
              child: Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelSubscription(BuildContext context, DocumentReference subscriptionRef) async {
    try {
      await subscriptionRef.update({'isActive': false});
      setState(() {
        hideButtons = true;  // Hide buttons after cancellation
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subscription Canceled')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error canceling subscription')),
      );
    }
  }
}

class SubscriptionRecord {
  final bool isActive;
  final String? serviceType;
  final Timestamp? startDate;
  final Timestamp? endDate;
  final Map<String, dynamic> paymentDetails;
  final DocumentReference reference;
  final DocumentReference? services;  // Reference to the service (plan) in the 'plans' collection

  SubscriptionRecord({
    required this.isActive,
    required this.serviceType,
    required this.startDate,
    required this.endDate,
    required this.paymentDetails,
    required this.reference,
    required this.services,  // Plan reference
  });

  factory SubscriptionRecord.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return SubscriptionRecord(
      isActive: data['isActive'] ?? false,
      serviceType: data['serviceType'] as String?,
      startDate: data['startDate'] as Timestamp?,
      endDate: data['endDate'] as Timestamp?,
      paymentDetails: data['paymentDetails'] as Map<String, dynamic>,
      reference: snapshot.reference,
      services: data['services'] as DocumentReference?,  // Plan reference field
    );
  }
}
