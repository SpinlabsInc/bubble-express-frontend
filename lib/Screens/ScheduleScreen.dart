import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class ScheduleScreen extends StatefulWidget {
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
  List<Map<String, dynamic>> plans = [];
  final List<String> serviceTypes = ['2-day', '3-day'];
  final List<String> daysOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final List<String> timeFrames = [
    '6:00 AM - 9:00 AM', '9:00 AM - 12:00 PM', '12:00 PM - 3:00 PM',
    '3:00 PM - 6:00 PM', '6:00 PM - 9:00 PM'
  ];

  GoogleMapController? mapController;
  Set<Marker> markers = {};

  @override
  void initState() {
    super.initState();
    fetchPlansFromFirebase();
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

  void handleServiceTypeSelection(String type) {
    setState(() {
      serviceType = type;
      selectedDays.clear();
      mainSelectedDay = null;
    });
  }

  // Function to update the location based on user interaction
  void _onMapTap(LatLng position, bool isPickupLocation) {
    setState(() {
      if (isPickupLocation) {
        pickupLocation = position;
        markers.removeWhere((m) => m.markerId.value == 'pickup');
        markers.add(Marker(markerId: MarkerId('pickup'), position: pickupLocation!, infoWindow: InfoWindow(title: 'Pickup Location')));

        // Automatically set drop location to pickup location
        dropLocation = pickupLocation;
        dropController.text = '${dropLocation!.latitude}, ${dropLocation!.longitude}';

        markers.removeWhere((m) => m.markerId.value == 'drop');
        markers.add(Marker(markerId: MarkerId('drop'), position: dropLocation!, infoWindow: InfoWindow(title: 'Drop Location')));

        pickupController.text = '${pickupLocation!.latitude}, ${pickupLocation!.longitude}';
      } else {
        dropLocation = position;
        markers.removeWhere((m) => m.markerId.value == 'drop');
        markers.add(Marker(markerId: MarkerId('drop'), position: dropLocation!, infoWindow: InfoWindow(title: 'Drop Location')));
        dropController.text = '${dropLocation!.latitude}, ${dropLocation!.longitude}';
      }
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
      if (serviceType == '2-day') {
        if (day == 'Monday' || day == 'Wednesday' || day == 'Friday') {
          selectedDays = ['Monday', 'Wednesday', 'Friday'];
        } else if (day == 'Tuesday' || day == 'Thursday' || day == 'Saturday') {
          selectedDays = ['Tuesday', 'Thursday', 'Saturday'];
        }
      } else if (serviceType == '3-day') {
        switch (day) {
          case 'Monday':
            selectedDays = ['Monday', 'Thursday', 'Sunday'];
            break;
          case 'Tuesday':
            selectedDays = ['Tuesday', 'Friday', 'Monday'];
            break;
          case 'Wednesday':
            selectedDays = ['Wednesday', 'Saturday', 'Tuesday'];
            break;
          case 'Thursday':
            selectedDays = ['Thursday', 'Sunday', 'Wednesday'];
            break;
          case 'Friday':
            selectedDays = ['Friday', 'Monday', 'Thursday'];
            break;
          case 'Saturday':
            selectedDays = ['Saturday', 'Tuesday', 'Friday'];
            break;
        }
      }
      calculateDeliveryDate(selectedDays.first);
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

      int dayIndex = daysOfWeek.indexOf(selectedDays.first);
      DateTime firstSelectedDate = now.add(Duration(days: (dayIndex + 7 - now.weekday) % 7));
      Timestamp startDateTimestamp = Timestamp.fromDate(firstSelectedDate);

      Map<String, dynamic> orderData = {
        'createdAt': now,
        'updatedAt': now,
        'isActive': true,
        'startDate': startDateTimestamp,
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
      };

      await FirebaseFirestore.instance.collection('subscriptions').add(orderData);

      // Show success message
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Your order has been submitted successfully!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();

                // Reset the form to initial state
                setState(() {
                  // Reset all selected values
                  selectedPlan = null;
                  serviceType = null;
                  selectedDays.clear();
                  timeSlots.clear();
                  pickupLocation = null;
                  dropLocation = null;
                  pickupController.clear();
                  dropController.clear();
                  deliveryDate = null;
                });
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      showError('Failed to submit order. Please try again.');
    }
  }

  bool isOrderComplete() {
    return selectedPlan != null &&
        serviceType != null &&
        selectedDays.isNotEmpty &&
        timeSlots.length == 2 &&
        pickupLocation != null &&
        dropLocation != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildPlanSelection(),
            if (selectedPlan != null) buildServiceTypeSelection(),
            if (serviceType != null) buildDaysSelection(),
            if (selectedDays.isNotEmpty) buildTimeSlotsSelection(),
            if (timeSlots.length == 2) buildGoogleMapSection(), // Show map after time slots are selected
            if (isOrderComplete()) buildOrderSummary(),
          ],
        ),
      ),
    );
  }

  Widget buildGoogleMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Pickup and Drop Locations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 300,  // Set appropriate height for the map
          child: GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: CameraPosition(
              target: LatLng(17.4239, 78.4738),  // Hussain Sagar, Hyderabad
              zoom: 14.0,  // Set zoom level
            ),
            markers: markers,
            myLocationEnabled: true,  // Enable "my location" button if permission is granted
            myLocationButtonEnabled: true,
            scrollGesturesEnabled: true,  // Enable scrolling gestures (moving map)
            zoomGesturesEnabled: true,    // Enable zooming gestures (pinch to zoom)
            tiltGesturesEnabled: true,    // Enable tilting gestures
            rotateGesturesEnabled: true,  // Enable rotating gestures
            onTap: (position) {
              showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (BuildContext context) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    height: 200,  // Increased height of the bottom sheet
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Location Action',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Set as Pickup Location'),
                          onTap: () {
                            _onMapTap(position, true);
                            Navigator.pop(context);  // Close the bottom sheet
                          },
                        ),
                        ListTile(
                          title: const Text('Set as Drop Location'),
                          onTap: () {
                            _onMapTap(position, false);
                            Navigator.pop(context);  // Close the bottom sheet
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        buildLocationFields(),  // Add text fields to display the pickup and drop locations
      ],
    );
  }

  Widget buildLocationFields() {
    return Column(
      children: [
        TextField(
          controller: pickupController,
          decoration: const InputDecoration(labelText: 'Pickup Location'),
          readOnly: true, // Read-only, updated from map
        ),
        const SizedBox(height: 8),
        TextField(
          controller: dropController,
          decoration: const InputDecoration(labelText: 'Drop Location'),
          onChanged: (value) {
            // If the drop location is manually edited, it can still be updated
            // You could parse the value to update `dropLocation` if needed
          },
        ),
      ],
    );
  }

  Widget buildPlanSelection() {
    if (plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
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
          serviceType == '2-day' ? 'Select Days for 2-Day Service' : 'Select Days for 3-Day Service',
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

            return GestureDetector(
              onTap: () => handleDaySelection(day),
              child: Container(
                width: (MediaQuery.of(context).size.width - 48) / 3,
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
                  child: Text(
                    day,
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
        if (deliveryDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Estimated delivery date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate!)}',
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
        if (pickupLocation != null)
          Text('Pickup Location: ${pickupLocation!.latitude}, ${pickupLocation!.longitude}', style: const TextStyle(fontSize: 16)),
        if (dropLocation != null)
          Text('Drop Location: ${dropLocation!.latitude}, ${dropLocation!.longitude}', style: const TextStyle(fontSize: 16)),
        if (deliveryDate != null)
          Text('Estimated Delivery Date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate!)}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: submitOrder,
            child: const Text('Submit Order'),
          ),
        ),
      ],
    );
  }
}
