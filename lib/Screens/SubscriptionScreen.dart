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
  late SubscriptionRecord subscription;  // Store subscription in state

  @override
  void initState() {
    super.initState();
    subscription = widget.subscription;  // Initialize with the passed subscription
    _fetchServiceName();  // Fetch service name initially
  }

  // Fetches the service name from Firebase and updates the UI
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
    final serviceType = subscription.serviceType ?? 'N/A';
    final amount = subscription.paymentDetails['amount'] ?? 'N/A';
    final startDate = subscription.startDate?.toDate().toLocal().toString().split(' ')[0] ?? 'N/A';
    final endDate = subscription.endDate?.toDate().toLocal().toString().split(' ')[0] ?? 'N/A';

    final DateTime? endDateObject = subscription.endDate?.toDate();
    int remainingDays = 0;
    if (endDateObject != null) {
      remainingDays = endDateObject.difference(DateTime.now()).inDays;
    }

    final remainingDaysText = remainingDays >= 0 ? '$remainingDays days' : 'Subscription Ended';
    final statusText = subscription.isActive ? 'Active' : 'Inactive';
    final statusColor = subscription.isActive ? Colors.green : Colors.red;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service Name: ${subscription.serviceName}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Service Type: $serviceType', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Amount: ₹$amount', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Start Date: $startDate', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('End Date: $endDate', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Remaining Days: $remainingDaysText', style: TextStyle(fontSize: 16, color: Colors.blue)),
            SizedBox(height: 8),
            Text('Status: $statusText', style: TextStyle(fontSize: 16, color: statusColor)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: subscription.isActive
                        ? () => _updateSubscriptionStatus(context, subscription.reference, false)
                        : () => _updateSubscriptionStatus(context, subscription.reference, true),
                    child: Text(subscription.isActive ? 'Pause' : 'Resume'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: subscription.isActive ? Colors.orange : Colors.green,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showUpgradeDialog(context),
                    child: Text('Upgrade'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
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

  // Updates the subscription status in Firebase and reflects it in the UI
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

  // Shows a dialog for upgrading the plan and confirms the upgrade
  Future<void> _showUpgradeDialog(BuildContext parentContext) async {
    final availablePlans = await _fetchAvailablePlans();
    final currentAmount = subscription.paymentDetails['amount'] ?? 0;

    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Upgrade Plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availablePlans.map((plan) {
              final isCurrentPlan = plan['id'] == subscription.services!.id;
              final priceDifference = plan['price'] - currentAmount;

              return ListTile(
                title: Text(plan['name']),
                subtitle: Text(priceDifference >= 0
                    ? '₹$priceDifference extra from current plan'
                    : '₹${priceDifference.abs()} less from current plan'),
                trailing: IconButton(
                  icon: Icon(Icons.info_outline),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlanDetailsPage(plan: plan),
                      ),
                    );
                  },
                ),
                enabled: !isCurrentPlan,
                tileColor: isCurrentPlan ? Colors.grey.shade300 : null,
                onTap: !isCurrentPlan
                    ? () {
                  Navigator.of(context).pop(); // Close the upgrade dialog
                  _confirmPlanUpgrade(parentContext, plan['id'], plan['price']); // Show confirmation dialog
                }
                    : null,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Confirms the plan upgrade and shows success or failure messages
  Future<void> _confirmPlanUpgrade(BuildContext parentContext, String newPlanId, int newPrice) async {
    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Upgrade'),
          content: Text('Are you sure you want to upgrade to the new plan?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog if the user cancels
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the confirmation dialog
                _upgradePlan(parentContext, newPlanId, newPrice); // Proceed with upgrading the plan
              },
              child: Text('Yes, Upgrade'),
            ),
          ],
        );
      },
    );
  }

  // Upgrades the subscription plan in Firebase and reflects the changes in the UI
  Future<void> _upgradePlan(BuildContext parentContext, String newPlanId, int newPrice) async {
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
        subscription = updatedSubscription;  // Update the state with the new subscription
      });

      // Refetch the service name for the newly upgraded plan
      await _fetchServiceName();

      // Show success message immediately after the Firebase update
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(content: Text('Plan upgraded successfully!')),
      );

    } catch (e) {
      // Handle errors by showing a failure message
      ScaffoldMessenger.of(parentContext).showSnackBar(
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
