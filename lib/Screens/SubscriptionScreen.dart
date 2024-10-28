import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'PlansPageScreen.dart';

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
              child: Text('No Subscriptions found'),
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
  late SubscriptionRecord subscription;

  @override
  void initState() {
    super.initState();
    subscription = widget.subscription;
    _fetchServiceName();
  }

  Future<void> _fetchServiceName() async {
    if (subscription.services != null) {
      try {
        DocumentSnapshot serviceDoc = await subscription.services!.get();

        if (serviceDoc.exists) {
          setState(() {
            subscription = subscription.copyWith(
              serviceName: serviceDoc['name'] ?? 'Unknown Service',
            );
          });
        } else {
          setState(() {
            subscription = subscription.copyWith(serviceName: 'Service not found');
          });
        }
      } catch (e) {
        setState(() {
          subscription = subscription.copyWith(serviceName: 'Error fetching service');
        });
      }
    } else {
      setState(() {
        subscription = subscription.copyWith(serviceName: 'No Service Available');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = subscription.paymentDetails['amount'] ?? 'N/A';
    final startDate = subscription.startDate?.toDate().toLocal().toString().split(' ')[0] ?? 'N/A';
    final endDate = subscription.endDate?.toDate().toLocal().toString().split(' ')[0] ?? 'N/A';

    final DateTime? startDateObject = subscription.startDate?.toDate();
    final DateTime? endDateObject = subscription.endDate?.toDate();
    int remainingDays = 0;

    if (startDateObject != null && endDateObject != null) {
      final today = DateTime.now();

      if (today.isAfter(endDateObject)) {
        remainingDays = 0;
      } else if (today.isBefore(startDateObject)) {
        remainingDays = endDateObject.difference(startDateObject).inDays;
      } else {
        remainingDays = endDateObject.difference(today).inDays;
      }
    }

    final remainingDaysText = remainingDays > 0 ? '$remainingDays days' : 'Subscription Ended';
    final statusText = subscription.isActive ? 'Active' : 'Inactive';
    final statusColor = subscription.isActive ? Colors.green : Colors.red;

    return Card(
      elevation: 0, // Remove shadow
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Adjust card margins
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Main padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${subscription.serviceName}', // Plan Name
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.info_outline), // Changed to "i" icon
                  onPressed: () {
                    // Redirect to PlansPageScreen when the icon is clicked
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PlansPageScreen()),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Service Type on the Left Side
                Text(
                  'Pickup every 2 days',
                  style: TextStyle(fontSize: 14),
                ),
                // Price on the Right Side
                Text(
                  '₹$amount',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: statusColor),
                SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 8),
            ExpansionTile(
              title: Text(
                'Hide Details',
                style: TextStyle(fontSize: 14),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0), // Details padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Start Date', startDate),
                      SizedBox(height: 4),
                      _buildDetailRow('End Date', endDate),
                      SizedBox(height: 4),
                      _buildDetailRow('Remaining Days', remainingDaysText),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Upgrade Plan Button with White Text
            ElevatedButton(
              onPressed: () => _showUpgradeDialog(context),
              child: Text(
                'Upgrade Plan',
                style: TextStyle(color: Colors.white), // White text for Upgrade button
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // Matching the color in the image
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 8),
            // Pause/Resume Subscription Button with Conditional Text Color
            ElevatedButton(
              onPressed: subscription.isActive
                  ? () => _updateSubscriptionStatus(context, subscription.reference, false)
                  : () => _updateSubscriptionStatus(context, subscription.reference, true),
              child: Text(
                subscription.isActive ? 'Pause Subscription' : 'Resume Subscription',
                style: TextStyle(
                  color: subscription.isActive ? Colors.black : Colors.white, // Pause -> Black, Resume -> White
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: subscription.isActive ? Colors.white : Colors.grey, // Matching pause/resume button color
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  // Feedback action
                },
                child: Text(
                  'Provide Feedback',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _updateSubscriptionStatus(BuildContext context, DocumentReference subscriptionRef, bool newStatus) async {
    try {
      await subscriptionRef.update({'isActive': newStatus});

      setState(() {
        subscription = subscription.copyWith(isActive: newStatus);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus ? 'Subscription Resumed' : 'Subscription Paused')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating subscription status')),
      );
    }
  }

  Future<void> _showUpgradeDialog(BuildContext context) async {
    final availablePlans = await _fetchAvailablePlans();
    final currentAmount = subscription.paymentDetails['amount'] ?? 0;
    String? selectedPlanId = subscription.services?.id;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Upgrade Your Plan', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose a new plan to upgrade your subscription.'),
                  SizedBox(height: 16),
                  Column(
                    children: availablePlans.map((plan) {
                      final isCurrentPlan = plan['id'] == subscription.services!.id;
                      return RadioListTile<String>(
                        value: plan['id'],
                        groupValue: selectedPlanId,
                        title: Text(
                          '${plan['name']} ${isCurrentPlan ? "(Current)" : ""}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isCurrentPlan ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onChanged: (String? value) {
                          if (!isCurrentPlan) {
                            setState(() {
                              selectedPlanId = value;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog without any action
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: selectedPlanId != subscription.services!.id
                      ? () async {
                    await _upgradePlan(context, selectedPlanId!, currentAmount);
                    Navigator.of(context).pop(); // Close the dialog after upgrading
                  }
                      : null, // Disable button if the same plan is selected
                  child: Text(
                    'Confirm Upgrade',
                    style: TextStyle(
                      color: Colors.black, // Black text for Confirm Upgrade button
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _upgradePlan(BuildContext context, String newPlanId, int newPrice) async {
    final subscriptionRef = subscription.reference;

    try {
      // Update the subscription with the new plan details in Firebase
      await subscriptionRef.update({
        'services': FirebaseFirestore.instance.collection('plans').doc(newPlanId),
        'paymentDetails.amount': newPrice,
      });

      // Refetch the updated subscription
      DocumentSnapshot updatedSubscriptionDoc = await subscriptionRef.get();
      SubscriptionRecord updatedSubscription = SubscriptionRecord.fromSnapshot(updatedSubscriptionDoc);

      setState(() {
        subscription = updatedSubscription; // Update the state with the new subscription
      });

      // Refetch the service name for the newly upgraded plan
      await _fetchServiceName();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan upgraded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error upgrading plan. Please try again.')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAvailablePlans() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('plans').get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': data['name'],
        'price': data['price'],
        'description': data['description'] ?? 'No description available'
      };
    }).toList();
  }
}

class SubscriptionRecord {
  final bool isActive;
  final String? serviceType;
  final Timestamp? startDate;
  final Timestamp? endDate;
  final Map<String, dynamic> paymentDetails;
  final DocumentReference reference;
  final DocumentReference? services;
  final String serviceName;

  SubscriptionRecord({
    required this.isActive,
    required this.serviceType,
    required this.startDate,
    required this.endDate,
    required this.paymentDetails,
    required this.reference,
    required this.services,
    this.serviceName = 'Loading...',
  });

  SubscriptionRecord copyWith({
    bool? isActive,
    String? serviceType,
    Timestamp? startDate,
    Timestamp? endDate,
    Map<String, dynamic>? paymentDetails,
    DocumentReference? reference,
    DocumentReference? services,
    String? serviceName,
  }) {
    return SubscriptionRecord(
      isActive: isActive ?? this.isActive,
      serviceType: serviceType ?? this.serviceType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      reference: reference ?? this.reference,
      services: services ?? this.services,
      serviceName: serviceName ?? this.serviceName,
    );
  }

  factory SubscriptionRecord.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return SubscriptionRecord(
      isActive: data['isActive'] ?? false,
      serviceType: data['serviceType'] as String?,
      startDate: data['startDate'] as Timestamp?,
      endDate: data['endDate'] as Timestamp?,
      paymentDetails: data['paymentDetails'] as Map<String, dynamic>,
      reference: snapshot.reference,
      services: data['services'] as DocumentReference?,
    );
  }
}
