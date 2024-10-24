import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'SubscriptionScreen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onTabTapped;

  HomeScreen({required this.onTabTapped});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class Plan {
  final String name;
  final double price;
  final String description;

  Plan({required this.name, required this.price, required this.description});
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

  Plan? currentPlan;
  List<Plan> availablePlans = [];
  List<Map<String, dynamic>> recentOrders = [];

  final List<Promotion> promotions = [
    Promotion(id: 1, title: '20% Off Your First Order', description: 'Use code FIRST20 at checkout'),
    Promotion(id: 2, title: 'Free Pickup on Orders Over ₹50', description: 'Limited time offer'),
    Promotion(id: 3, title: 'Refer a Friend, Get ₹100 Off', description: 'Share your referral code now'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentPlan();
    _fetchAvailablePlans();
    _fetchRecentOrders(); // Fetch the recent orders when the widget is initialized
  }

  Future<void> _fetchCurrentPlan() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('subscriptions')
            .where('userId', isEqualTo: _firestore.collection('users').doc(currentUser.uid))
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
              currentPlan = Plan(
                name: planSnapshot['name'],
                price: planSnapshot['price'].toDouble(),
                description: planSnapshot['description'],
              );
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

  Future<void> _fetchAvailablePlans() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('plans').get();

      List<Plan> fetchedPlans = snapshot.docs.map((doc) {
        return Plan(
          name: doc['name'],
          price: doc['price'].toDouble(),
          description: doc['description'],
        );
      }).toList();

      setState(() {
        availablePlans = fetchedPlans;
      });
    } catch (e) {
      print('Error fetching available plans: $e');
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome to LaundryApp'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPromotionsSection(),
            SizedBox(height: 16),
            _buildQuickActionsSection(context),
            SizedBox(height: 16),
            _buildCurrentPlanSection(),
            SizedBox(height: 16),
            _buildAvailablePlansSection(),
            SizedBox(height: 16),
            _buildRecentOrdersSection(),
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
          return GestureDetector(
            onTap: () {
              _showPromotionDialog(promo);
            },
            child: Container(
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
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    promo.description,
                    style: TextStyle(fontSize: 14, color: Colors.blue[600]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPromotionDialog(Promotion promo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(promo.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(promo.description),
              SizedBox(height: 16),
              Text("This is some demo information for this promotion."),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("Close"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                widget.onTabTapped(1); // Switch to ScheduleScreen
              },
              child: Text("Order Now"),
            ),
          ],
        );
      },
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
                widget.onTabTapped(1); // Switch to ScheduleScreen
              },
            ),
            _buildQuickAction(
              icon: Icons.shopping_cart,
              color: Colors.green,
              label: 'Track Order',
              onTap: () {
                widget.onTabTapped(2); // Switch to OrderTrackingScreen
              },
            ),
            _buildQuickAction(
              icon: Icons.notifications,
              color: Colors.yellow[700]!,
              label: 'Notifications',
              onTap: () {
                widget.onTabTapped(3); // Switch to NotificationsScreen
              },
            ),
            _buildQuickAction(
              icon: Icons.subscriptions,
              color: Colors.red,
              label: 'Subscriptions',
              onTap: () {
                // Use Navigator.push to open SubscriptionScreen without bottom navigation
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SubscriptionScreen()),
                );
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

  Widget _buildCurrentPlanSection() {
    if (currentPlan == null) {
      return Center(
        child: Text(
          'No current plan found.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Container(
      width: double.infinity, // Make it fit the screen width
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
            '${currentPlan!.name} - ₹${currentPlan!.price.toStringAsFixed(2)}/month',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            currentPlan!.description,
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity, // Make the button fit the container width
            child: ElevatedButton(
              onPressed: () {
                widget.onTabTapped(1); // Switch to the ScheduleScreen (index 1 for tab navigation)
              },
              child: Text('Upgrade Plan'),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAvailablePlansSection() {
    if (availablePlans.isEmpty) {
      return Center(
        child: Text(
          'No plans available.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Container(
      width: double.infinity, // Make it fit the screen width
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
          Column(
            children: availablePlans.map((plan) {
              return Container(
                margin: EdgeInsets.only(bottom: 8), // Add margin between items
                padding: EdgeInsets.all(12),
                width: double.infinity, // Make the container fit the screen width
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${plan.name} - ₹${plan.price.toStringAsFixed(2)}/month',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      plan.description,
                      style: TextStyle(fontSize: 14),
                      maxLines: 2, // Ensure text fits within the height limit
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersSection() {
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
            Center(
              child: Text(
                'No recent orders found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
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
                ],
              );
            }).toList(),
          SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: double.infinity, // Make button fit the container width
              child: ElevatedButton(
                onPressed: () {
                  widget.onTabTapped(2); // Switch to OrderTrackingScreen
                },
                child: Text('View All Orders'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
