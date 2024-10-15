import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'NotificationsScreen.dart';
import 'OrderTracking.dart';
import 'ProfileScreen.dart';
import 'ScheduleScreen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class Plan {
  final String name;
  final double price;
  final List<String> features;

  Plan({required this.name, required this.price, required this.features});
}

class Promotion {
  final int id;
  final String title;
  final String description;

  Promotion({required this.id, required this.title, required this.description});
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String currentPlan = 'Basic Plan';
  List<Map<String, dynamic>> recentOrders = [];

  final List<Plan> plans = [
    Plan(name: 'Basic Plan', price: 29.99, features: ['Wash', 'Fold', 'Iron']),
    Plan(name: 'Premium Plan', price: 49.99, features: ['Premium Wash', 'Fold', 'Iron', 'Stain Removal']),
    Plan(name: 'Premium Plus Plan', price: 69.99, features: ['All Premium features', 'Dry Cleaning', 'Saree Rolling', 'Shoe Cleaning']),
  ];

  final List<Promotion> promotions = [
    Promotion(id: 1, title: '20% Off Your First Order', description: 'Use code FIRST20 at checkout'),
    Promotion(id: 2, title: 'Free Pickup on Orders Over \$50', description: 'Limited time offer'),
    Promotion(id: 3, title: 'Refer a Friend, Get \$10 Off', description: 'Share your referral code now'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchRecentOrders(); // Fetch the recent orders when the widget is initialized
  }

  // Fetch the recent orders for the current logged-in user
  Future<void> _fetchRecentOrders() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentReference userRef = _firestore.collection('users').doc(currentUser.uid);
        QuerySnapshot snapshot = await _firestore
            .collection('orders')
            .where('userId', isEqualTo: userRef)
            .orderBy('createdAt', descending: true)
            .limit(3) // Fetch the 3 most recent orders
            .get();

        setState(() {
          recentOrders = snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'status': doc['status'] ?? 'No status',
              'createdAt': (doc['createdAt'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? 'No date',
            };
          }).toList();
        });
      } catch (e) {
        print('Error fetching recent orders: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Plan? currentPlanDetails = plans.firstWhere((plan) => plan.name == currentPlan, orElse: () => plans[0]);

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome to LaundryApp'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPromotionsSection(),
            SizedBox(height: 16),
            _buildQuickActionsSection(context),
            SizedBox(height: 16),
            _buildCurrentPlanSection(currentPlanDetails),
            SizedBox(height: 16),
            _buildAvailablePlansSection(),
            SizedBox(height: 16),
            _buildRecentOrdersSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionsSection() {
    return Container(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: promotions.length,
        itemBuilder: (context, index) {
          Promotion promo = promotions[index];
          return Container(
            width: 250,
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                ),
                SizedBox(height: 8),
                Text(
                  promo.description,
                  style: TextStyle(fontSize: 14, color: Colors.blue[600]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildQuickAction(
              icon: Icons.schedule,
              color: Colors.blue,
              label: 'Schedule',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ScheduleScreen()));
              },
            ),
            _buildQuickAction(
              icon: Icons.shopping_cart,
              color: Colors.green,
              label: 'Track Order',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => OrderTrackingScreen()));
              },
            ),
            _buildQuickAction(
              icon: Icons.notifications,
              color: Colors.yellow[700]!,
              label: 'Notifications',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsScreen()));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 30,
            child: Icon(icon, color: color, size: 30),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanSection(Plan currentPlanDetails) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Plan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '${currentPlanDetails.name} - \$${currentPlanDetails.price.toStringAsFixed(2)}/month',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen()));
            },
            child: Text('Upgrade Plan'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailablePlansSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Plans',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          ...plans.map((plan) {
            bool isCurrentPlan = plan.name == currentPlan;
            return Container(
              margin: EdgeInsets.symmetric(vertical: 4),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrentPlan ? Colors.blue[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plan.name} - \$${plan.price.toStringAsFixed(2)}/month',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    plan.features.join(', '),
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          if (recentOrders.isEmpty)
            Text('No recent orders found.', style: TextStyle(color: Colors.grey))
          else
            ...recentOrders.map((order) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order['id']}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Status: ${order['status']}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Text(
                    'Date: ${order['createdAt']}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Divider(),
                ],
              );
            }).toList(),
          SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => OrderTrackingScreen()));
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
}
