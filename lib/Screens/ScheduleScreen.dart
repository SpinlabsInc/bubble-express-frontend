// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// class ScheduleScreen extends StatefulWidget {
//   @override
//   _ScheduleScreenState createState() => _ScheduleScreenState();
// }
//
// class _ScheduleScreenState extends State<ScheduleScreen> {
//   String? selectedPlan;
//   String? serviceType;
//   List<String> selectedDays = [];
//   String? mainSelectedDay; // Track the manually selected day
//   List<String> timeSlots = [];
//   String? pickupLocation = '';
//   String? dropLocation = '';
//   DateTime? deliveryDate;
//
//   final List<Map<String, dynamic>> plans = [
//     {'name': 'Basic Plan', 'price': 29.99, 'features': ['Wash', 'Fold', 'Iron']},
//     {'name': 'Premium Plan', 'price': 49.99, 'features': ['Premium Wash', 'Fold', 'Iron', 'Stain Removal']},
//     {'name': 'Premium Plus Plan', 'price': 69.99, 'features': ['All Premium features', 'Dry Cleaning']}
//   ];
//
//   final List<String> serviceTypes = ['2-day', '3-day'];
//
//   final List<String> daysOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
//
//   final List<String> timeFrames = [
//     '6:00 AM - 9:00 AM', '9:00 AM - 12:00 PM', '12:00 PM - 3:00 PM',
//     '3:00 PM - 6:00 PM', '6:00 PM - 9:00 PM'
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   // Automatically calculate available days based on the selected service type
//   void handleServiceTypeSelection(String type) {
//     setState(() {
//       serviceType = type;
//       selectedDays.clear();  // Reset the selected days when switching service types
//       mainSelectedDay = null;
//     });
//   }
//
//   // Handle day selection with logic for both 2-day and 3-day services
//   void handleDaySelection(String day) {
//     final today = DateTime.now().weekday;
//     final int currentDayIndex = daysOfWeek.indexOf(day);
//
//     if (currentDayIndex == today - 1) {
//       showError('We do not service on the current day. Please choose another day.');
//       return;
//     }
//
//     setState(() {
//       mainSelectedDay = day; // Mark the manually selected day
//       selectedDays.clear(); // Clear previously selected days
//
//       if (serviceType == '2-day') {
//         // 2-day service selection logic
//         if (day == 'Monday' || day == 'Wednesday' || day == 'Friday') {
//           selectedDays = ['Monday', 'Wednesday', 'Friday'];
//         } else if (day == 'Tuesday' || day == 'Thursday' || day == 'Saturday') {
//           selectedDays = ['Tuesday', 'Thursday', 'Saturday'];
//         }
//       } else if (serviceType == '3-day') {
//         // 3-day service selection logic
//         switch (day) {
//           case 'Monday':
//             selectedDays = ['Monday', 'Thursday', 'Sunday'];
//             break;
//           case 'Tuesday':
//             selectedDays = ['Tuesday', 'Friday', 'Monday'];
//             break;
//           case 'Wednesday':
//             selectedDays = ['Wednesday', 'Saturday', 'Tuesday'];
//             break;
//           case 'Thursday':
//             selectedDays = ['Thursday', 'Sunday', 'Wednesday'];
//             break;
//           case 'Friday':
//             selectedDays = ['Friday', 'Monday', 'Thursday'];
//             break;
//           case 'Saturday':
//             selectedDays = ['Saturday', 'Tuesday', 'Friday'];
//             break;
//         }
//       }
//       calculateDeliveryDate(selectedDays.first);
//     });
//   }
//
//   void calculateDeliveryDate(String pickupDay) {
//     final today = DateTime.now();
//     int pickupDayIndex = daysOfWeek.indexOf(pickupDay);
//     int daysUntilPickup = (pickupDayIndex + 7 - today.weekday) % 7;
//     DateTime pickupDate = today.add(Duration(days: daysUntilPickup));
//
//     setState(() {
//       if (serviceType == '2-day') {
//         deliveryDate = pickupDate.add(Duration(days: 2));
//       } else if (serviceType == '3-day') {
//         deliveryDate = pickupDate.add(Duration(days: 3));
//       }
//     });
//   }
//
//   void handleTimeSlotSelection(String slot) {
//     setState(() {
//       if (timeSlots.contains(slot)) {
//         timeSlots.remove(slot);
//       } else if (timeSlots.length < 2) {
//         timeSlots.add(slot);
//       } else {
//         showError('You can only select 2 time slots.');
//       }
//     });
//   }
//
//   void showError(String message) {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Error'),
//         content: Text(message),
//         actions: [
//           TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('OK')),
//         ],
//       ),
//     );
//   }
//
//   bool isOrderComplete() {
//     return selectedPlan != null && serviceType != null && selectedDays.isNotEmpty && timeSlots.length == 2 && pickupLocation != '' && dropLocation != '';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Schedule Service'),
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             buildPlanSelection(),
//             if (selectedPlan != null) buildServiceTypeSelection(),
//             if (serviceType != null) buildDaysSelection(),
//             if (selectedDays.isNotEmpty) buildTimeSlotsSelection(),
//             if (timeSlots.length == 2) buildLocationInput(),
//             if (isOrderComplete()) buildOrderSummary()
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Fixed Plan Selection with Flexible Grid
//   Widget buildPlanSelection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text('Select a Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//         SizedBox(height: 8),
//         GridView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: plans.length,
//           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 2, // Updated for 2 columns to avoid overflow
//             childAspectRatio: 3 / 2, // Adjusted aspect ratio for better rendering
//             crossAxisSpacing: 8,
//             mainAxisSpacing: 8,
//           ),
//           itemBuilder: (context, index) {
//             final plan = plans[index];
//             return GestureDetector(
//               onTap: () => setState(() => selectedPlan = plan['name']),
//               child: Container(
//                 padding: EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   border: Border.all(color: selectedPlan == plan['name'] ? Colors.blue : Colors.grey),
//                   borderRadius: BorderRadius.circular(10),
//                   color: selectedPlan == plan['name'] ? Colors.blue[50] : Colors.white,
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(plan['name'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                     Text('\$${plan['price']}/month', style: TextStyle(fontSize: 14)),
//                     SizedBox(height: 4),
//                     Text(plan['features'].join(', '), style: TextStyle(fontSize: 12)),
//                   ],
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
//
//   Widget buildServiceTypeSelection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 16),
//         Text('Select Service Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//         SizedBox(height: 8),
//         Row(
//           children: serviceTypes.map((type) {
//             return Expanded(
//               child: GestureDetector(
//                 onTap: () => handleServiceTypeSelection(type), // Update service type and selected days
//                 child: Container(
//                   padding: EdgeInsets.all(12),
//                   margin: EdgeInsets.symmetric(horizontal: 4),
//                   decoration: BoxDecoration(
//                     color: serviceType == type ? Colors.blue : Colors.grey[200],
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Center(
//                     child: Text(
//                       type,
//                       style: TextStyle(
//                         color: serviceType == type ? Colors.white : Colors.black,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           }).toList(),
//         ),
//       ],
//     );
//   }
//
//   Widget buildDaysSelection() {
//     final today = DateTime.now().weekday;
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 16),
//         Text(serviceType == '2-day' ? 'Select Days for 2-Day Service' : 'Select Days for 3-Day Service',
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//         SizedBox(height: 8),
//         Wrap(
//           spacing: 8,
//           children: daysOfWeek.skip(1).map((day) {
//             final dayIndex = daysOfWeek.indexOf(day);
//             return GestureDetector(
//               onTap: () => handleDaySelection(day),
//               child: Container(
//                 padding: EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: mainSelectedDay == day
//                       ? Colors.orange
//                       : selectedDays.contains(day)
//                       ? Colors.blue
//                       : Colors.grey[200],
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   day,
//                   style: TextStyle(
//                     color: dayIndex == today - 1 ? Colors.red : selectedDays.contains(day) ? Colors.white : Colors.black,
//                   ),
//                 ),
//               ),
//             );
//           }).toList(),
//         ),
//         if (deliveryDate != null)
//           Padding(
//             padding: const EdgeInsets.only(top: 8.0),
//             child: Text(
//               'Estimated delivery date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate!)}',
//               style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
//             ),
//           ),
//       ],
//     );
//   }
//
//   Widget buildTimeSlotsSelection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 16),
//         Text('Select Time Slots', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//         SizedBox(height: 8),
//         Text('Choose 2 time slots (we recommend one in the morning and one in the evening):'),
//         SizedBox(height: 8),
//         Wrap(
//           spacing: 8,
//           children: timeFrames.map((slot) {
//             return GestureDetector(
//               onTap: () => handleTimeSlotSelection(slot),
//               child: Container(
//                 padding: EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: timeSlots.contains(slot) ? Colors.blue : Colors.grey[200],
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   slot,
//                   style: TextStyle(
//                     color: timeSlots.contains(slot) ? Colors.white : Colors.black,
//                   ),
//                 ),
//               ),
//             );
//           }).toList(),
//         ),
//       ],
//     );
//   }
//
//   Widget buildLocationInput() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 16),
//         Text('Enter Pickup/Drop Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//         SizedBox(height: 8),
//         TextField(
//           decoration: InputDecoration(
//             labelText: 'Pickup Location',
//             border: OutlineInputBorder(),
//           ),
//           onChanged: (value) {
//             setState(() {
//               pickupLocation = value;
//               if (dropLocation == '') dropLocation = value;
//             });
//           },
//         ),
//         SizedBox(height: 8),
//         TextField(
//           decoration: InputDecoration(
//             labelText: 'Drop Location',
//             border: OutlineInputBorder(),
//           ),
//           onChanged: (value) => setState(() => dropLocation = value),
//         ),
//       ],
//     );
//   }
//
//   Widget buildOrderSummary() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 16),
//         Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//         SizedBox(height: 8),
//         Text('Selected Plan: $selectedPlan'),
//         Text('Service Type: $serviceType'),
//         Text('Service Days: ${selectedDays.join(', ')}'),
//         Text('Time Slots: ${timeSlots.join(', ')}'),
//         Text('Pickup Location: $pickupLocation'),
//         Text('Drop Location: $dropLocation'),
//         if (deliveryDate != null)
//           Text('Estimated Delivery Date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate!)}'),
//         SizedBox(height: 16),
//         ElevatedButton(
//           onPressed: () {
//             // Handle order submission
//             showError('Your order has been submitted successfully!');
//           },
//           child: Text('Submit Order'),
//         ),
//       ],
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleScreen extends StatefulWidget {
  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? selectedPlan;
  String? serviceType;
  List<String> selectedDays = [];
  String? mainSelectedDay; // Track the manually selected day
  List<String> timeSlots = [];
  String? pickupLocation = '';
  String? dropLocation = '';
  DateTime? deliveryDate;

  final List<Map<String, dynamic>> plans = [
    {'name': 'Basic Plan', 'price': 29.99, 'features': ['Wash', 'Fold', 'Iron']},
    {'name': 'Premium Plan', 'price': 49.99, 'features': ['Premium Wash', 'Fold', 'Iron', 'Stain Removal']},
    {'name': 'Premium Plus Plan', 'price': 69.99, 'features': ['All Premium features', 'Dry Cleaning']}
  ];

  final List<String> serviceTypes = ['2-day', '3-day'];

  final List<String> daysOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  final List<String> timeFrames = [
    '6:00 AM - 9:00 AM', '9:00 AM - 12:00 PM', '12:00 PM - 3:00 PM',
    '3:00 PM - 6:00 PM', '6:00 PM - 9:00 PM'
  ];

  @override
  void initState() {
    super.initState();
  }

  // Automatically calculate available days based on the selected service type
  void handleServiceTypeSelection(String type) {
    setState(() {
      serviceType = type;
      selectedDays.clear();  // Reset the selected days when switching service types
      mainSelectedDay = null;
    });
  }

  // Function to handle 2-day service selection logic
  void selectDaysFor2DayService(String day) {
    if (day == 'Monday' || day == 'Wednesday' || day == 'Friday') {
      selectedDays = ['Monday', 'Wednesday', 'Friday'];
    } else if (day == 'Tuesday' || day == 'Thursday' || day == 'Saturday') {
      selectedDays = ['Tuesday', 'Thursday', 'Saturday'];
    }
  }

  // Function to handle 3-day service selection logic
  void selectDaysFor3DayService(String day) {
    switch (day) {
      case 'Monday':
        selectedDays = ['Monday', 'Thursday'];
        break;
      case 'Tuesday':
        selectedDays = ['Tuesday', 'Friday'];
        break;
      case 'Wednesday':
        selectedDays = ['Wednesday', 'Saturday'];
        break;
      case 'Thursday':
        selectedDays = ['Thursday', 'Sunday'];
        break;
      case 'Friday':
        selectedDays = ['Friday', 'Monday'];
        break;
      case 'Saturday':
        selectedDays = ['Saturday', 'Tuesday'];
        break;
    }
  }

  // Handle day selection
  void handleDaySelection(String day) {
    final today = DateTime.now().weekday;
    final int currentDayIndex = daysOfWeek.indexOf(day);

    if (currentDayIndex == today - 1) {
      showError('We do not service on the current day. Please choose another day.');
      return;
    }

    setState(() {
      mainSelectedDay = day; // Mark the manually selected day
      selectedDays.clear(); // Clear previously selected days

      if (serviceType == '2-day') {
        selectDaysFor2DayService(day); // Call the function for 2-day service logic
      } else if (serviceType == '3-day') {
        selectDaysFor3DayService(day); // Call the function for 3-day service logic
      }

      calculateDeliveryDate(selectedDays.first);
    });
  }

  void calculateDeliveryDate(String pickupDay) {
    final today = DateTime.now();
    int pickupDayIndex = daysOfWeek.indexOf(pickupDay);
    int daysUntilPickup = (pickupDayIndex + 7 - today.weekday) % 7;
    DateTime pickupDate = today.add(Duration(days: daysUntilPickup));

    setState(() {
      if (serviceType == '2-day') {
        deliveryDate = pickupDate.add(Duration(days: 2));
      } else if (serviceType == '3-day') {
        deliveryDate = pickupDate.add(Duration(days: 3));
      }
    });
  }

  void handleTimeSlotSelection(String slot) {
    setState(() {
      if (timeSlots.contains(slot)) {
        timeSlots.remove(slot);
      } else if (timeSlots.length < 2) {
        timeSlots.add(slot);
      } else {
        showError('You can only select 2 time slots.');
      }
    });
  }

  void showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('OK')),
        ],
      ),
    );
  }

  bool isOrderComplete() {
    return selectedPlan != null && serviceType != null && selectedDays.isNotEmpty && timeSlots.length == 2 && pickupLocation != '' && dropLocation != '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule Service'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildPlanSelection(),
            if (selectedPlan != null) buildServiceTypeSelection(),
            if (serviceType != null) buildDaysSelection(),
            if (selectedDays.isNotEmpty) buildTimeSlotsSelection(),
            if (timeSlots.length == 2) buildLocationInput(),
            if (isOrderComplete()) buildOrderSummary()
          ],
        ),
      ),
    );
  }

  // Fixed Plan Selection with Flexible Grid
  Widget buildPlanSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select a Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: plans.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // Updated for 2 columns to avoid overflow
            childAspectRatio: 3 / 2, // Adjusted aspect ratio for better rendering
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final plan = plans[index];
            return GestureDetector(
              onTap: () => setState(() => selectedPlan = plan['name']),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: selectedPlan == plan['name'] ? Colors.blue : Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                  color: selectedPlan == plan['name'] ? Colors.blue[50] : Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan['name'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('\$${plan['price']}/month', style: TextStyle(fontSize: 14)),
                    SizedBox(height: 4),
                    Text(plan['features'].join(', '), style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildServiceTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text('Select Service Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Row(
          children: serviceTypes.map((type) {
            return Expanded(
              child: GestureDetector(
                onTap: () => handleServiceTypeSelection(type), // Update service type and selected days
                child: Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: serviceType == type ? Colors.blue : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      type,
                      style: TextStyle(
                        color: serviceType == type ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget buildDaysSelection() {
    final today = DateTime.now().weekday;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(serviceType == '2-day' ? 'Select Days for 2-Day Service' : 'Select Days for 3-Day Service',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: daysOfWeek.skip(1).map((day) {
            final dayIndex = daysOfWeek.indexOf(day);
            return GestureDetector(
              onTap: () => handleDaySelection(day),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mainSelectedDay == day
                      ? Colors.orange
                      : selectedDays.contains(day)
                      ? Colors.blue
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    color: dayIndex == today - 1 ? Colors.red : selectedDays.contains(day) ? Colors.white : Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (deliveryDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Estimated delivery date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate!)}',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget buildTimeSlotsSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text('Select Time Slots', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Choose 2 time slots (we recommend one in the morning and one in the evening):'),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: timeFrames.map((slot) {
            return GestureDetector(
              onTap: () => handleTimeSlotSelection(slot),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: timeSlots.contains(slot) ? Colors.blue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  slot,
                  style: TextStyle(
                    color: timeSlots.contains(slot) ? Colors.white : Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget buildLocationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text('Enter Pickup/Drop Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            labelText: 'Pickup Location',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              pickupLocation = value;
              if (dropLocation == '') dropLocation = value;
            });
          },
        ),
        SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            labelText: 'Drop Location',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => dropLocation = value),
        ),
      ],
    );
  }

  Widget buildOrderSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Selected Plan: $selectedPlan'),
        Text('Service Type: $serviceType'),
        Text('Service Days: ${selectedDays.join(', ')}'),
        Text('Time Slots: ${timeSlots.join(', ')}'),
        Text('Pickup Location: $pickupLocation'),
        Text('Drop Location: $dropLocation'),
        if (deliveryDate != null)
          Text('Estimated Delivery Date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate!)}'),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            // Handle order submission
            showError('Your order has been submitted successfully!');
          },
          child: Text('Submit Order'),
        ),
      ],
    );
  }
}
