import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

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
            print('Fetching subscriptions...');
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Error fetching subscriptions: ${snapshot.error}');
            return Center(child: Text('An error occurred: ${snapshot.error}'));
          }

          final subscriptions = snapshot.data ?? [];

          print('Number of subscriptions fetched: ${subscriptions.length}');

          if (subscriptions.isEmpty) {
            print('No subscriptions found for the current user.');
            return Center(
              child: Text(
                'No Subscriptions found',
                style: GoogleFonts.sora(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              final subscription = subscriptions[index];
              print('Displaying subscription: ${subscription.reference.id}');
              return SubscriptionCard(subscription: subscription);
            },
          );
        },
      ),
    );
  }

  /// Fetch the subscriptions for the currently logged-in user.
  Future<List<SubscriptionRecord>> fetchSubscriptions() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;

    if (user == null) {
      print('Error: No user is currently logged in.');
      throw Exception('No user is logged in.');
    }

    final String userId = user.uid;
    print('Current logged-in userId: $userId');

    // Get a reference to the logged-in user's document in the 'users' collection
    DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);

    try {
      // Fetch subscriptions where the 'userId' field matches the current user's DocumentReference
      final querySnapshot = await FirebaseFirestore.instance
          .collection('subscriptions')  // Use the correct collection name
          .where('userId', isEqualTo: userDocRef)  // Compare with DocumentReference
          .get();

      print('Subscriptions fetched successfully for userId: $userId, ${querySnapshot.docs.length} records found.');

      return querySnapshot.docs.map((doc) {
        print('Subscription fetched: ${doc.id}');
        return SubscriptionRecord.fromSnapshot(doc);
      }).toList();
    } catch (e) {
      print('Error fetching subscriptions for userId: $userId - $e');
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

  @override
  void initState() {
    super.initState();
    isActive = widget.subscription.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final planType = widget.subscription.planType ?? 'N/A';  // Plan type is now directly accessed from the root
    final amount = widget.subscription.paymentDetails['amount'] ?? 'N/A';
    final transactionId = widget.subscription.paymentDetails['transactionId'] ?? 'N/A';
    final startDate = widget.subscription.startDate?.toDate().toLocal().toString().split(' ')[0] ?? 'N/A';
    final endDate = widget.subscription.endDate?.toDate().toLocal().toString().split(' ')[0] ?? 'N/A';
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
            Text('Plan Type: $planType', style: GoogleFonts.sora(fontSize: 18)),
            SizedBox(height: 8),
            Text('Amount: ₹$amount', style: GoogleFonts.sora(fontSize: 16)),
            SizedBox(height: 8),
            Text('Transaction ID: $transactionId', style: GoogleFonts.sora(fontSize: 16)),
            SizedBox(height: 8),
            Text('Start Date: $startDate', style: GoogleFonts.sora(fontSize: 16)),
            SizedBox(height: 8),
            Text('End Date: $endDate', style: GoogleFonts.sora(fontSize: 16)),
            SizedBox(height: 8),
            Text(
              'Status: $statusText',
              style: GoogleFonts.sora(
                fontSize: 16,
                color: statusColor,
              ),
            ),
            SizedBox(height: 16),
            // Show the Pause button if the subscription is active, otherwise show the Resume button
            ElevatedButton(
              onPressed: isActive
                  ? () => _updateSubscriptionStatus(context, widget.subscription.reference, false)
                  : () => _updateSubscriptionStatus(context, widget.subscription.reference, true),
              child: Text(isActive ? 'Pause' : 'Resume'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.orange : Colors.green,
                minimumSize: Size(double.infinity, 50),  // Fit to screen width
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateSubscriptionStatus(BuildContext context, DocumentReference subscriptionRef, bool newStatus) async {
    try {
      print('${newStatus ? "Resuming" : "Pausing"} subscription: ${subscriptionRef.id}');
      await subscriptionRef.update({'isActive': newStatus});

      setState(() {
        isActive = newStatus; // Update the local state immediately to reflect the new status
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newStatus ? 'Subscription Resumed' : 'Subscription Paused'),
      ));
    } catch (e) {
      print('Error updating subscription: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error updating subscription'),
      ));
    }
  }
}

class SubscriptionRecord {
  final bool isActive;
  final String? planType;  // Plan type is accessed directly from the root of the document
  final Timestamp? startDate;
  final Timestamp? endDate;
  final Map<String, dynamic> paymentDetails;
  final DocumentReference reference;

  SubscriptionRecord({
    required this.isActive,
    required this.planType,
    required this.startDate,
    required this.endDate,
    required this.paymentDetails,
    required this.reference,
  });

  factory SubscriptionRecord.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return SubscriptionRecord(
      isActive: data['isActive'] ?? false,
      planType: data['planType'] as String?,  // Fetch planType from root level
      startDate: data['startDate'] as Timestamp?,
      endDate: data['endDate'] as Timestamp?,
      paymentDetails: data['paymentDetails'] as Map<String, dynamic>,
      reference: snapshot.reference,
    );
  }
}
