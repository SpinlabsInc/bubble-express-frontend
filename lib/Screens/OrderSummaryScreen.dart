import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderSummaryScreen extends StatelessWidget {
  final String selectedPlan;
  final String serviceType;
  final List<String> selectedDays;
  final List<String> timeSlots;
  final DateTime selectedPickupDate;
  final DateTime deliveryDate;
  final DateTime endDate;

  OrderSummaryScreen({
    required this.selectedPlan,
    required this.serviceType,
    required this.selectedDays,
    required this.timeSlots,
    required this.selectedPickupDate,
    required this.deliveryDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate the plan duration in days
    final int planDuration = endDate.difference(selectedPickupDate).inDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Summary'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selected Plan: $selectedPlan', style: const TextStyle(fontSize: 16)),
            Text('Service Type: $serviceType', style: const TextStyle(fontSize: 16)),
            if (selectedDays.isNotEmpty)
              Text(
                'Service Days: ${selectedDays.take(3).join(', ')}', // Only take the first 3 days
                style: const TextStyle(fontSize: 16),
              ),
            Text('Time Slots: ${timeSlots.join(', ')}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Divider(color: Colors.grey),

            // Show start date
            Text(
              'Selected Pickup Date: ${DateFormat('MMMM dd, yyyy').format(selectedPickupDate)}',
              style: const TextStyle(fontSize: 16),
            ),

            // Show delivery date
            Text(
              'Delivery Date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate)}',
              style: const TextStyle(fontSize: 16),
            ),

            // Show end date (28 days from pickup date)
            Text(
              'End Date: ${DateFormat('MMMM dd, yyyy').format(endDate)}',
              style: const TextStyle(fontSize: 16),
            ),

            // Display the plan duration
            const SizedBox(height: 8),
            Text(
              'Plan Duration: $planDuration days', // Display the calculated plan duration
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
            ),

            const SizedBox(height: 16),

            // Confirm and Cancel buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Implement the confirmation logic here
                      Navigator.pop(context, true); // Return true on confirmation
                    },
                    child: const Text('Confirm'),
                  ),
                ),
                const SizedBox(width: 16), // Add some space between buttons
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, false); // Return false on cancellation
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
