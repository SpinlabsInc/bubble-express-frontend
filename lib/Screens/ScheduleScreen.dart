import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

class ScheduleScreen extends StatefulWidget {
  final String? planId; // Accepting the planId passed from the NotificationsScreen
  final String? orderId; // Added to handle existing order updates

  ScheduleScreen({this.planId, this.orderId});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? selectedPlan;
  String? serviceType;
  List<String> selectedDays = [];
  String? mainSelectedDay;
  List<String> timeSlots = [];

  LatLng? pickupLocation;
  LatLng? dropLocation;
  TextEditingController pickupController = TextEditingController();
  TextEditingController dropController = TextEditingController();

  DateTime? deliveryDate;
  DateTime? selectedPickupDate;
  List<Map<String, dynamic>> plans = [];

  bool isPickupConfirmed = false;
  bool isDropConfirmed = false;
  bool showPickupMap = false;
  bool showDropMap = false;

  final List<String> serviceTypes = ['Pickup every 2 days', 'Pickup every 3 days'];
  final List<String> daysOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final List<String> timeFrames = [
    '6:00 AM - 9:00 AM', '9:00 AM - 12:00 PM', '12:00 PM - 3:00 PM',
    '3:00 PM - 6:00 PM', '6:00 PM - 9:00 PM'
  ];

  GoogleMapController? mapController;
  Set<Marker> markers = {};

  List<Map<String, dynamic>> userOrders = [];

  @override
  void initState() {
    super.initState();
    fetchPlansFromFirebase();
    if (widget.orderId != null) {
      fetchExistingOrder(widget.orderId!); // Fetching existing order data
    } else {
      fetchUserOrders(); // For new orders, fetch all the user’s existing orders
    }

    // If a planId is passed from the notification, fetch the plan details
    if (widget.planId != null) {
      fetchPlanById(widget.planId);
    }
  }

  // Fetch existing order details and pre-fill the form
  Future<void> fetchExistingOrder(String orderId) async {
    try {
      DocumentSnapshot orderSnapshot =
      await FirebaseFirestore.instance.collection('subscriptions').doc(orderId).get();

      if (orderSnapshot.exists) {
        setState(() {
          selectedPlan = orderSnapshot['services'].id;
          serviceType = orderSnapshot['serviceType'];
          selectedPickupDate = orderSnapshot['startDate'].toDate();
          deliveryDate = orderSnapshot['endDate'].toDate();
          pickupController.text = orderSnapshot['pickupLoc'].toString();
          dropController.text = orderSnapshot['dropLoc'].toString();
          pickupLocation = LatLng(orderSnapshot['pickupLoc'].latitude, orderSnapshot['pickupLoc'].longitude);
          dropLocation = LatLng(orderSnapshot['dropLoc'].latitude, orderSnapshot['dropLoc'].longitude);
          timeSlots = orderSnapshot['timeSlots'].cast<String>();
          selectedDays = orderSnapshot['selectedDays'].cast<String>();
        });
      }
    } catch (error) {
      showError('Failed to fetch order details.');
    }
  }

  Future<void> fetchPlanById(String? planId) async {
    if (planId == null) return;

    try {
      DocumentSnapshot planDoc = await FirebaseFirestore.instance.collection('plans').doc(planId).get();

      // You can now use the plan details as needed (e.g., set the selectedPlan)
      setState(() {
        selectedPlan = planId; // Assuming the planId refers to the selected plan
      });
    } catch (error) {
      showError("Error fetching plan details.");
    }
  }

  Future<void> fetchPlansFromFirebase() async {
    try {
      CollectionReference plansRef = FirebaseFirestore.instance.collection('plans');
      QuerySnapshot snapshot = await plansRef.get();

      List<Map<String, dynamic>> fetchedPlans = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'] ?? '',
          'price': doc['price'] ?? 0.0,
          'description': doc['description'] ?? '',
          'isPremium': doc['isPremium'] ?? false,
          'createdAt': doc['createdAt']?.toDate(),
          'updatedAt': doc['updatedAt']?.toDate()
        };
      }).toList();

      setState(() {
        plans = fetchedPlans;
      });
    } catch (error) {
      showError("Error fetching plans");
    }
  }

  Future<void> fetchUserOrders() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return; // User not logged in, no need to proceed

      String userId = user.uid;
      CollectionReference subscriptionsRef = FirebaseFirestore.instance.collection('subscriptions');
      QuerySnapshot snapshot = await subscriptionsRef
          .where('userId', isEqualTo: FirebaseFirestore.instance.collection('users').doc(userId))
          .get();

      // Fetch the plan name along with subscription data
      List<Map<String, dynamic>> fetchedOrders = await Future.wait(snapshot.docs.map((doc) async {
        DocumentReference servicesRef = doc['services'];
        DocumentSnapshot planSnapshot = await servicesRef.get(); // Fetch plan details

        // Only fetch the plan name
        String? planName = planSnapshot.exists ? planSnapshot['name'] : 'No plan name';

        return {
          'id': doc.id,
          'pickupLoc': doc['pickupLoc'],
          'dropLoc': doc['dropLoc'],
          'serviceType': doc['serviceType'],
          'startDate': doc['startDate']?.toDate(),
          'endDate': doc['endDate']?.toDate(),
          'paymentDetails': doc['paymentDetails'],
          'planName': planName, // Only store the plan name
        };
      }).toList());

      setState(() {
        userOrders = fetchedOrders;
      });
    } catch (error) {
      showError('Error fetching your orders.');
    }
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance.collection('subscriptions').doc(orderId).update({'isActive': false});
      setState(() {
        userOrders.removeWhere((order) => order['id'] == orderId);
      });
      showSuccess('Order canceled successfully.');
    } catch (error) {
      showError('Failed to cancel the order.');
    }
  }

  Future<void> showPlanUpgradeDialog(String orderId) async {
    final currentOrder = userOrders.firstWhere((order) => order['id'] == orderId);
    String? currentPlanName = currentOrder['planName'];

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Upgrade Plan'),
          content: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('plans').get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              if (!snapshot.hasData) {
                return const Text('No plans available.');
              }

              final plans = snapshot.data!.docs;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: plans.map((planDoc) {
                  String planName = planDoc['name'];
                  bool isCurrentPlan = planName == currentPlanName;

                  return ListTile(
                    title: Text(planName),
                    subtitle: Text(isCurrentPlan ? 'This is your current plan' : planDoc['description']),
                    trailing: Text('₹${planDoc['price']}'),
                    onTap: isCurrentPlan ? null : () {
                      Navigator.of(context).pop();
                      showConfirmUpgradeDialog(orderId, planDoc.id); // Pass the selected plan ID
                    },
                    tileColor: isCurrentPlan ? Colors.grey[300] : null,
                    enabled: !isCurrentPlan, // Disable the current plan
                  );
                }).toList(),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> showConfirmUpgradeDialog(String orderId, String? selectedPlanId) async {
    // Capture the current context before doing anything asynchronous
    final BuildContext dialogContext = context;

    // Display the confirmation dialog
    await showDialog(
      context: dialogContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Plan Upgrade'),
          content: const Text('Are you sure you want to upgrade your plan?'),
          actions: [
            TextButton(
              onPressed: () {
                // Dismiss the confirmation dialog
                Navigator.of(context, rootNavigator: true).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // First dismiss the confirmation modal
                Navigator.of(context, rootNavigator: true).pop();

                // Show success modal immediately
                _showSuccessModal(dialogContext);

                // Perform the upgrade operation asynchronously in the background
                updateSubscriptionPlan(orderId, selectedPlanId);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  // Define a function to show the success modal immediately
  void _showSuccessModal(BuildContext context) {
    // Ensure the modal is called only once by calling showDialog once
    showDialog(
      context: context,
      barrierDismissible: false,  // Prevent closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Plan upgraded successfully!'),
          actions: [
            TextButton(
              onPressed: () {
                // Dismiss the success modal and ensure no dialogs remain
                Navigator.of(context, rootNavigator: true).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateSubscriptionPlan(String orderId, String? selectedPlanId) async {
    try {
      DocumentReference planRef = FirebaseFirestore.instance.collection('plans').doc(selectedPlanId);

      // Update the Firestore subscription with the new plan reference
      await FirebaseFirestore.instance.collection('subscriptions').doc(orderId).update({
        'services': planRef,
        'updatedAt': Timestamp.now(),
      });

      // Fetch the plan's name from Firestore (the upgraded plan)
      DocumentSnapshot planSnapshot = await planRef.get();
      String? updatedPlanName = planSnapshot.exists ? planSnapshot['name'] : 'No plan name';

      // Update the local state (userOrders) with the new plan name
      setState(() {
        for (var order in userOrders) {
          if (order['id'] == orderId) {
            order['planName'] = updatedPlanName; // Update the plan name in the local state
          }
        }
      });

      // Create a new notification in the 'notifications' collection
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'createdAt': Timestamp.now(),
          'data': 'Plan Upgrade',
          'isRead': false,
          'message': 'Your plan has been successfully upgraded to $updatedPlanName.',
          'title': 'Plan Upgrade Successful',
          'userId': FirebaseFirestore.instance.collection('users').doc(user.uid),
        });
      }

    } catch (error) {
      showError('Failed to upgrade the plan.');
    }
  }

  void handleServiceTypeSelection(String type) {
    setState(() {
      serviceType = type;
      selectedDays.clear();
      mainSelectedDay = null;
    });
  }

  void handleDaySelection(String day) {
    final today = DateTime.now().weekday;
    final int currentDayIndex = daysOfWeek.indexOf(day);

    if (currentDayIndex == today - 1) {
      showError('We do not service on the current day. Please choose another day.');
      return;
    }

    setState(() {
      mainSelectedDay = day;
      selectedDays.clear();

      if (serviceType == 'Pickup every 2 days') {
        DateTime firstSelectedDay = DateTime.now().add(Duration(days: (currentDayIndex + 7 - today) % 7));
        selectedPickupDate = firstSelectedDay;

        DateTime nextDay = firstSelectedDay;
        while (selectedDays.length < 5) {
          if (nextDay.weekday != DateTime.sunday) {
            selectedDays.add(daysOfWeek[nextDay.weekday % 7]);
          }
          nextDay = addDaysSkippingSunday(nextDay, 2);
        }
      } else if (serviceType == 'Pickup every 3 days') {
        selectedDays.add(day);
        DateTime firstSelectedDay = DateTime.now().add(Duration(days: (currentDayIndex + 7 - today) % 7));
        selectedPickupDate = firstSelectedDay;

        DateTime nextDay1 = addDaysSkippingSunday(firstSelectedDay, 3);
        selectedDays.add(daysOfWeek[nextDay1.weekday % 7]);

        DateTime nextDay2 = addDaysSkippingSunday(nextDay1, 3);
        selectedDays.add(daysOfWeek[nextDay2.weekday % 7]);
      }

      calculateDeliveryDate(selectedDays.first);
    });
  }

  DateTime addDaysSkippingSunday(DateTime fromDate, int daysToAdd) {
    DateTime resultDate = fromDate;
    int addedDays = 0;

    while (addedDays < daysToAdd) {
      resultDate = resultDate.add(Duration(days: 1));
      if (resultDate.weekday != DateTime.sunday) {
        addedDays++;
      }
    }

    return resultDate;
  }

  void calculateDeliveryDate(String pickupDay) {
    final today = DateTime.now();
    int pickupDayIndex = daysOfWeek.indexOf(pickupDay);
    int daysUntilPickup = (pickupDayIndex + 7 - today.weekday) % 7;
    DateTime pickupDate = today.add(Duration(days: daysUntilPickup));

    setState(() {
      if (serviceType == 'Pickup every 2 days') {
        deliveryDate = addDaysSkippingSunday(pickupDate, 2);
      } else if (serviceType == 'Pickup every 3 days') {
        deliveryDate = addDaysSkippingSunday(pickupDate, 3);
      }
    });
  }

  bool isOrderComplete() {
    return selectedPlan != null &&
        serviceType != null &&
        selectedDays.isNotEmpty &&
        timeSlots.length == 2 &&
        pickupLocation != null &&
        dropLocation != null;
  }

  Widget buildOrderSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(color: Colors.grey),
        const SizedBox(height: 8),
        Text('Selected Plan: $selectedPlan', style: const TextStyle(fontSize: 16)),
        Text('Service Type: $serviceType', style: const TextStyle(fontSize: 16)),
        Text('Service Days: ${selectedDays.join(', ')}', style: const TextStyle(fontSize: 16)),
        Text('Time Slots: ${timeSlots.join(', ')}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        const Divider(color: Colors.grey),
        if (selectedPickupDate != null)
          Text(
            'Selected Pickup Date: ${DateFormat('MMMM dd, yyyy').format(selectedPickupDate!)}',
            style: const TextStyle(fontSize: 16),
          ),
        if (deliveryDate != null)
          Text(
            'Estimated Delivery Date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate!)}',
            style: const TextStyle(fontSize: 16),
          ),
        if (pickupLocation != null)
          Text('Pickup Location: ${pickupController.text}', style: const TextStyle(fontSize: 16)),
        if (dropLocation != null)
          Text('Drop Location: ${dropController.text}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: submitOrder,
            child: Text(widget.orderId != null ? 'Update Order' : 'Submit Order'),
          ),
        ),
      ],
    );
  }

  Future<void> submitOrder() async {
    try {
      if (pickupLocation == null || dropLocation == null) {
        showError('Please select both pickup and drop locations.');
        return;
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showError('No user is logged in. Please log in to place an order.');
        return;
      }
      String userId = user.uid;

      DateTime now = DateTime.now();
      DocumentReference planRef = FirebaseFirestore.instance.collection('plans').doc(selectedPlan);
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);

      Map<String, dynamic> orderData = {
        'createdAt': now,
        'updatedAt': now,
        'isActive': true,
        'startDate': Timestamp.fromDate(selectedPickupDate!),
        'endDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
        'pickupLoc': GeoPoint(pickupLocation!.latitude, pickupLocation!.longitude),
        'dropLoc': GeoPoint(dropLocation!.latitude, dropLocation!.longitude),
        'serviceType': serviceType,
        'paymentDetails': {
          'amount': 100,
          'transactionId': "dummyTransaction123",
        },
        'services': planRef,
        'userId': userRef,
        'timeSlots': timeSlots, // Adding timeSlots
        'selectedDays': selectedDays, // Adding selectedDays
      };

      if (widget.orderId != null) {
        // Update the existing order
        await FirebaseFirestore.instance.collection('subscriptions').doc(widget.orderId).update(orderData);
        // Create a notification for the update
        await FirebaseFirestore.instance.collection('notifications').add({
          'createdAt': now,
          'data': 'Subscription Update',
          'isRead': false,
          'message': 'Your subscription has been successfully updated.',
          'title': 'Subscription Updated',
          'userId': userRef,
        });
        showSuccess('Order updated successfully!');
      } else {
        // Create a new order
        await FirebaseFirestore.instance.collection('subscriptions').add(orderData);
        showSuccess('Order created successfully!');
      }

      // Clear form on success
      setState(() {
        selectedPlan = null;
        serviceType = null;
        selectedDays.clear();
        timeSlots.clear();
        pickupLocation = null;
        dropLocation = null;
        pickupController.clear();
        dropController.clear();
        deliveryDate = null;
        selectedPickupDate = null;
        isPickupConfirmed = false;
        isDropConfirmed = false;
      });
    } catch (error) {
      showError('Failed to submit order. Please try again.');
    }
  }

  Widget buildUserOrders() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: userOrders.length,
      itemBuilder: (context, index) {
        final order = userOrders[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Service Type: ${order['serviceType']}', style: const TextStyle(fontSize: 16)),
                Text('Pickup Location: LatLng(${order['pickupLoc'].latitude}, ${order['pickupLoc'].longitude})'),
                Text('Drop Location: LatLng(${order['dropLoc'].latitude}, ${order['dropLoc'].longitude})'),
                Text('Start Date: ${DateFormat('MMMM dd, yyyy').format(order['startDate'])}'),
                Text('End Date: ${DateFormat('MMMM dd, yyyy').format(order['endDate'])}'),
                Text('Amount Paid: ₹${order['paymentDetails']['amount']}'),

                if (order['planName'] != null)
                  Text('Current Plan: ${order['planName']}', style: const TextStyle(fontSize: 16)),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Populate the form with existing order data for editing
                          setState(() {
                            selectedPlan = order['planName']; // Use the current plan name
                            serviceType = order['serviceType'];
                            pickupLocation = LatLng(order['pickupLoc'].latitude, order['pickupLoc'].longitude);
                            dropLocation = LatLng(order['dropLoc'].latitude, order['dropLoc'].longitude);
                            pickupController.text = 'LatLng(${order['pickupLoc'].latitude}, ${order['pickupLoc'].longitude})';
                            dropController.text = 'LatLng(${order['dropLoc'].latitude}, ${order['dropLoc'].longitude})';
                            selectedPickupDate = order['startDate'];
                            deliveryDate = order['endDate'];
                            timeSlots = order['timeSlots'].cast<String>();
                            selectedDays = order['selectedDays'].cast<String>();
                          });

                          // Reuse submitOrder for updating the order
                          submitOrder();
                        },
                        child: const Text('Update'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => cancelOrder(order['id']),
                        child: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => showPlanUpgradeDialog(order['id']),
                    child: const Text('Upgrade your plan'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildOrderPlacement() {
    if (plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildPlanSelection(),
        if (selectedPlan != null) buildServiceTypeSelection(),
        if (serviceType != null) buildDaysSelection(),
        if (selectedDays.isNotEmpty) buildTimeSlotsSelection(),
        if (timeSlots.length == 2) buildGoogleMapSection(),
        if (isOrderComplete()) buildOrderSummary(),
      ],
    );
  }

  Widget buildPlanSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select a Plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: plans.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3.2 / 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final plan = plans[index];
            return GestureDetector(
              onTap: () => setState(() => selectedPlan = plan['id']),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: selectedPlan == plan['id'] ? Colors.blue : Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                  color: selectedPlan == plan['id'] ? Colors.blue[50] : Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('₹${plan['price']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(plan['description'], style: const TextStyle(fontSize: 12)),
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
        const SizedBox(height: 16),
        const Text('Select Service Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: serviceTypes.map((type) {
            return Expanded(
              child: GestureDetector(
                onTap: () => handleServiceTypeSelection(type),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
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
        const SizedBox(height: 16),
        Text(
          serviceType == 'Pickup every 2 days' ? 'Select Days for Pickup every 2 Days' : 'Select Days for Pickup every 3 Days',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: daysOfWeek.skip(1).map((day) {
            final dayIndex = daysOfWeek.indexOf(day);
            final isSelected = selectedDays.contains(day);
            final isToday = dayIndex == today - 1;

            DateTime currentDate = DateTime.now().add(Duration(days: (dayIndex + 7 - today) % 7));

            String formattedDate = DateFormat('dd MMM').format(currentDate);

            return GestureDetector(
              onTap: () => handleDaySelection(day),
              child: SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 3,
                height: 80,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isToday ? Colors.red : (isSelected ? Colors.blue : Colors.grey),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (selectedPickupDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Selected Pickup Date: ${DateFormat('MMMM dd, yyyy').format(selectedPickupDate!)}',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        if (deliveryDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Estimated Delivery Date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate!)}',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget buildTimeSlotsSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Select Time Slots', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Choose 2 time slots (we recommend one in the morning and one in the evening):'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: timeFrames.map((slot) {
            final isSelected = timeSlots.contains(slot);
            return GestureDetector(
              onTap: () => handleTimeSlotSelection(slot),
              child: Container(
                width: (MediaQuery.of(context).size.width - 48) / 3,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    slot,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget buildGoogleMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Pickup Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: pickupController,
          decoration: const InputDecoration(labelText: 'Enter Pickup Location'),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _geocodeAddress(value, isPickupLocation: true);
            }
          },
          readOnly: isPickupConfirmed,
        ),
        const SizedBox(height: 16),
        if (showPickupMap && !isPickupConfirmed)
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) => true, // Disable scroll notification to block parent scroll
            child: SizedBox(
              height: 300,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {}, // Disable parent scroll while interacting with the map
                child: GoogleMap(
                  onMapCreated: (controller) => mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: pickupLocation ?? LatLng(17.4239, 78.4738),  // Default location
                    zoom: 14.0,  // Initial zoom level
                  ),
                  markers: markers,
                  zoomGesturesEnabled: true,  // Enable pinch-to-zoom
                  scrollGesturesEnabled: true,  // Enable map scrolling gestures
                  tiltGesturesEnabled: true,  // Enable tilt gestures
                  rotateGesturesEnabled: true,  // Enable rotate gestures
                  onCameraMove: (CameraPosition position) {
                    // Update the camera position when the map moves
                    setState(() {
                      pickupLocation = position.target;
                    });
                  },
                  onTap: (position) {
                    _onMapTap(position, true);  // Handle map tap
                  },
                ),
              ),
            ),
          ),
        if (showPickupMap && !isPickupConfirmed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isPickupConfirmed = true;
                        showPickupMap = false;
                        dropController.text = pickupController.text;
                        dropLocation = pickupLocation;
                      });
                    },
                    child: const Text('Confirm'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        showPickupMap = false;
                        pickupController.clear();
                        pickupLocation = null;
                        markers.removeWhere((m) => m.markerId.value == 'pickup');
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ),
        if (isPickupConfirmed) buildDropLocationSection(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget buildDropLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Drop Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: dropController,
          decoration: const InputDecoration(labelText: 'Enter Drop Location'),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _geocodeAddress(value, isPickupLocation: false);
            }
          },
          readOnly: isDropConfirmed,
        ),
        const SizedBox(height: 16),
        if (showDropMap && !isDropConfirmed)
          SizedBox(
            height: 300,
            child: GoogleMap(
              onMapCreated: (controller) => mapController = controller,
              initialCameraPosition: CameraPosition(
                target: dropLocation ?? LatLng(17.4239, 78.4738),
                zoom: 14.0,
              ),
              markers: markers,
              onTap: (position) {
                _onMapTap(position, false);
              },
            ),
          ),
        if (showDropMap && !isDropConfirmed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isDropConfirmed = true;
                        showDropMap = false;
                      });
                    },
                    child: const Text('Confirm'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        showDropMap = false;
                        dropController.clear();
                        dropLocation = null;
                        markers.removeWhere((m) => m.markerId.value == 'drop');
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _geocodeAddress(String address, {required bool isPickupLocation}) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      LatLng position = LatLng(locations[0].latitude, locations[0].longitude);

      if (isPickupLocation) {
        pickupLocation = position;
        markers.removeWhere((m) => m.markerId.value == 'pickup');
        markers.add(Marker(markerId: MarkerId('pickup'), position: pickupLocation!, infoWindow: InfoWindow(title: 'Pickup Location')));

        mapController?.animateCamera(CameraUpdate.newLatLng(pickupLocation!));
        setState(() {
          showPickupMap = true;
        });
      } else {
        dropLocation = position;
        markers.removeWhere((m) => m.markerId.value == 'drop');
        markers.add(Marker(markerId: MarkerId('drop'), position: dropLocation!, infoWindow: InfoWindow(title: 'Drop Location')));

        mapController?.animateCamera(CameraUpdate.newLatLng(dropLocation!));
        setState(() {
          showDropMap = true;
        });
      }
    } catch (e) {
      showError("Error finding location. Please try again.");
    }
  }

  void _onMapTap(LatLng position, bool isPickupLocation) {
    setState(() {
      if (isPickupLocation) {
        pickupLocation = position;
        markers.removeWhere((m) => m.markerId.value == 'pickup');
        markers.add(Marker(markerId: MarkerId('pickup'), position: pickupLocation!, infoWindow: InfoWindow(title: 'Pickup Location')));
        pickupController.text = '${pickupLocation!.latitude}, ${pickupLocation!.longitude}';
      } else {
        dropLocation = position;
        markers.removeWhere((m) => m.markerId.value == 'drop');
        markers.add(Marker(markerId: MarkerId('drop'), position: dropLocation!, infoWindow: InfoWindow(title: 'Drop Location')));
        dropController.text = '${dropLocation!.latitude}, ${dropLocation!.longitude}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: userOrders.isNotEmpty ? buildUserOrders() : buildOrderPlacement(),
      ),
    );
  }

  void showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void showSuccess(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }
}
