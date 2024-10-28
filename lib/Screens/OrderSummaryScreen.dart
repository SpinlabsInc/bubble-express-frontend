import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';  // Assuming MainScreen is imported here for navigation

class OrderSummaryScreen extends StatelessWidget {
  final String selectedPlan;
  final double planPrice;
  final String serviceType;
  final List<String> selectedDays;
  final List<String> timeSlots;
  final DateTime selectedPickupDate;
  final DateTime deliveryDate;
  final DateTime endDate;
  final String pickupLocation;
  final Future<bool> Function(String?) onConfirmOrder;

  OrderSummaryScreen({
    required this.selectedPlan,
    required this.planPrice,
    required this.serviceType,
    required this.selectedDays,
    required this.timeSlots,
    required this.selectedPickupDate,
    required this.deliveryDate,
    required this.endDate,
    required this.pickupLocation,
    required this.onConfirmOrder,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate the plan duration in days
    final int planDuration = endDate.difference(selectedPickupDate).inDays;

    // Dropdown value for selecting location type
    String? selectedLocationType;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Summary'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Number and Plan Information
            const Text(
              'Order #ORD-12345',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),

            // Plan Details with Edit and Upgrade buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedPlan,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      serviceType,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Edit Order Button
                    ElevatedButton.icon(
                      onPressed: () {
                        // Handle edit order functionality
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Order'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Upgrade Plan Button
                    ElevatedButton.icon(
                      onPressed: () {
                        // Handle upgrade plan functionality
                      },
                      icon: const Icon(Icons.upgrade, size: 18),
                      label: const Text('Upgrade Plan'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Pickup Date and Icon in a Single Row with Shortened Month Format
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.grey),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Pickup Dates: ${DateFormat('MMM dd, yyyy').format(selectedPickupDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis, // Prevent overflow issues
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Time Slots
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Time Slots: ${timeSlots.join(', ')}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Pickup Location Dropdown
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedLocationType,
                    items: const [
                      DropdownMenuItem(
                        value: 'Home',
                        child: Text('Home'),
                      ),
                      DropdownMenuItem(
                        value: 'Work',
                        child: Text('Work'),
                      ),
                      DropdownMenuItem(
                        value: null,
                        child: Text('None'),
                      ),
                    ],
                    onChanged: (value) {
                      selectedLocationType = value;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Save Location As',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Plan Duration
            Text(
              'Plan Duration: $planDuration days',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 16),

            // Spacer to push content upwards
            const Spacer(),

            // Total Amount Section (moved to bottom)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount:', style: TextStyle(fontSize: 18)),
                Text('₹${planPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Create New Order Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  onConfirmOrder(selectedLocationType).then((_) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Success'),
                        content: const Text('Order created successfully!'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => MainScreen(initialIndex: 1)),
                                    (route) => false,
                              );
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }).catchError((error) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Error'),
                        content: Text(error.toString()),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  });
                },
                label: const Text('Create New Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Cancel Order Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => MainScreen(initialIndex: 1)),
                        (route) => false,
                  );
                },
                label: const Text('Cancel Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
