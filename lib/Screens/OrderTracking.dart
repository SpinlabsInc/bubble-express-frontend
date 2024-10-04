import 'package:flutter/material.dart';

class OrderTrackingScreen extends StatefulWidget {
  @override
  _OrderTrackingScreenState createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  List<Map<String, dynamic>> orders = [
    {
      'id': '1234',
      'status': 'In Progress',
      'needsApproval': true,
      'items': [
        {'name': 'Shirt', 'quantity': 3},
        {'name': 'Pants', 'quantity': 2},
        {'name': 'Dress', 'quantity': 1},
      ],
      'totalAmount': 45.99,
      'pickupDate': '2023-06-01',
      'pickupTime': '10:00 AM',
      'expectedDeliveryDate': '2023-06-03',
      'expectedDeliveryTime': '2:00 PM',
    },
    {
      'id': '1233',
      'status': 'Delivered',
      'needsApproval': false,
      'items': [
        {'name': 'Jacket', 'quantity': 1},
        {'name': 'Sweater', 'quantity': 2},
      ],
      'totalAmount': 35.50,
      'pickupDate': '2023-05-28',
      'pickupTime': '11:30 AM',
      'expectedDeliveryDate': '2023-05-30',
      'expectedDeliveryTime': '3:00 PM',
    },
  ];

  void approvePhoto(String orderId) {
    setState(() {
      orders = orders.map((order) {
        if (order['id'] == orderId) {
          order['needsApproval'] = false;
        }
        return order;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Track Orders')),
      body: Padding(
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
                    Text('Order #${order['id']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Status: ${order['status']}', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8),
                    Text('Order Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(order['items'].length, (itemIndex) {
                        final item = order['items'][itemIndex];
                        return Text('${item['name']} x ${item['quantity']}', style: TextStyle(fontSize: 14));
                      }),
                    ),
                    SizedBox(height: 8),
                    Text('Total Amount: \$${order['totalAmount'].toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Pickup: ${order['pickupDate']} at ${order['pickupTime']}', style: TextStyle(fontSize: 14)),
                    Text('Expected Delivery: ${order['expectedDeliveryDate']} at ${order['expectedDeliveryTime']}', style: TextStyle(fontSize: 14)),
                    if (order['needsApproval']) ...[
                      SizedBox(height: 16),
                      Text('Approve Pickup Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Image.network('https://via.placeholder.com/300x200', height: 150, fit: BoxFit.cover),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => approvePhoto(order['id']),
                            icon: Icon(Icons.check, color: Colors.white),
                            label: Text('Approve'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                          SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Handle rejection
                            },
                            icon: Icon(Icons.close, color: Colors.white),
                            label: Text('Reject'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
