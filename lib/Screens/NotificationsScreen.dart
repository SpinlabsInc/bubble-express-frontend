import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ScheduleScreen.dart';

class NotificationsScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch notifications for the logged-in user
  Stream<QuerySnapshot> fetchUserNotifications() {
    User? user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userDocRef)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Get the icon based on notification type
  Widget getIcon(String type) {
    switch (type) {
      case 'order':
        return Icon(Icons.shopping_bag, color: Colors.blue, size: 30);
      case 'subscription':
        return Icon(Icons.credit_card, color: Colors.green, size: 30);
      default:
        return Icon(Icons.notifications, color: Colors.yellow[700], size: 30);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: fetchUserNotifications(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text("No notifications available"));
            }

            final notifications = snapshot.data!.docs;

            return ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                bool isRead = notification['isRead'] ?? false;

                return GestureDetector(
                  onTap: () async {
                    // Mark notification as read
                    await markNotificationAsRead(notification.id);

                    // Navigate to ScheduleScreen with the plan details
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScheduleScreen(
                          planId: notification['data'], // Assuming `data` holds the plan ID
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.grey[300] : Colors.white, // Dull color if read
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        getIcon(notification['data'] ?? 'default'),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification['message'] ?? 'No message',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                notification['createdAt'] != null
                                    ? (notification['createdAt'] as Timestamp).toDate().toString()
                                    : 'Time not available',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
