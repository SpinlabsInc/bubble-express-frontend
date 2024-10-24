import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

import 'EditOrderScreen.dart';
import 'OrderSummaryScreen.dart';

class ScheduleScreen extends StatefulWidget {
  final String? planId;

  ScheduleScreen({this.planId});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? selectedPlan;
  String? serviceType;
  LatLng? homePickupLoc;
  LatLng? homeDropLoc;
  LatLng? workPickupLoc;
  LatLng? workDropLoc;
  LatLng? tempHomePickupLoc;
  LatLng? tempHomeDropLoc;
  LatLng? tempWorkPickupLoc;
  LatLng? tempWorkDropLoc;
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
  bool showSubscriptionCard = false;
  bool _isMapInteracting = false;

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
    fetchUserOrders();

    if (widget.planId != null) {
      fetchPlanById(widget.planId);
    }
  }

  Future<void> fetchPlanById(String? planId) async {
    if (planId == null) return;

    try {
      DocumentSnapshot planDoc = await FirebaseFirestore.instance.collection('plans').doc(planId).get();

      setState(() {
        selectedPlan = planId;
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
      if (user == null) return;

      String userId = user.uid;
      CollectionReference subscriptionsRef = FirebaseFirestore.instance.collection('subscriptions');
      QuerySnapshot snapshot = await subscriptionsRef
          .where('userId', isEqualTo: FirebaseFirestore.instance.collection('users').doc(userId))
          .get();

      List<Map<String, dynamic>> fetchedOrders = await Future.wait(snapshot.docs.map((doc) async {
        DocumentReference servicesRef = doc['services'];
        DocumentSnapshot planSnapshot = await servicesRef.get();

        String? planName = planSnapshot.exists ? planSnapshot['name'] : 'No plan name';

        // Retrieve the location tree structure
        Map<String, dynamic> locationData = doc['location'] ?? {};

        return {
          'id': doc.id,
          'pickupLoc': locationData['pickup'] != null
              ? LatLng(locationData['pickup'].latitude, locationData['pickup'].longitude)
              : null,
          'dropLoc': locationData['drop'] != null
              ? LatLng(locationData['drop'].latitude, locationData['drop'].longitude)
              : null,
          'homePickupLoc': locationData['home']?['pickup'] != null
              ? LatLng(locationData['home']['pickup'].latitude, locationData['home']['pickup'].longitude)
              : null,
          'homeDropLoc': locationData['home']?['drop'] != null
              ? LatLng(locationData['home']['drop'].latitude, locationData['home']['drop'].longitude)
              : null,
          'workPickupLoc': locationData['work']?['pickup'] != null
              ? LatLng(locationData['work']['pickup'].latitude, locationData['work']['pickup'].longitude)
              : null,
          'workDropLoc': locationData['work']?['drop'] != null
              ? LatLng(locationData['work']['drop'].latitude, locationData['work']['drop'].longitude)
              : null,
          'serviceType': doc['serviceType'],
          'startDate': doc['startDate']?.toDate(),
          'endDate': doc['endDate']?.toDate(),
          'paymentDetails': doc['paymentDetails'],
          'planName': planName,
          'deliveryDate': doc['deliveryDate'] != null ? (doc['deliveryDate'] as Timestamp).toDate() : null,
        };
      }).toList());

      setState(() {
        userOrders = fetchedOrders;
      });
    } catch (error) {
      showError('Error fetching your orders.');
    }
  }

  void _showSaveLocationDialog({required bool isPickupLocation}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Location'),
          content: const Text('Would you like to save this location as Home or Work?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _saveLocationAs('home', isPickupLocation: isPickupLocation); // Save as Home
                Navigator.of(context).pop();
              },
              child: const Text('Home'),
            ),
            TextButton(
              onPressed: () {
                _saveLocationAs('work', isPickupLocation: isPickupLocation); // Save as Work
                Navigator.of(context).pop();
              },
              child: const Text('Work'),
            ),
          ],
        );
      },
    );
  }

  void _saveLocationAs(String type, {required bool isPickupLocation}) {
    setState(() {
      if (type == 'home') {
        if (isPickupLocation) {
          tempHomePickupLoc = pickupLocation;
          tempHomeDropLoc = pickupLocation;  // Automatically set drop to pickup location
          dropController.text = pickupController.text;  // Update the drop text field with the same value
        } else {
          tempHomeDropLoc = dropLocation;
        }
      } else if (type == 'work') {
        if (isPickupLocation) {
          tempWorkPickupLoc = pickupLocation;
          tempWorkDropLoc = pickupLocation;  // Automatically set drop to pickup location
          dropController.text = pickupController.text;  // Update the drop text field with the same value
        } else {
          tempWorkDropLoc = dropLocation;
        }
      }
      showSuccess('Location saved temporarily.');
    });

    Navigator.of(context).pop();  // Close the popup after selection
  }


  Future<void> loadSavedLocations() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (userDoc.exists) {
      setState(() {
        if (userDoc['location.pickup'] != null) {
          GeoPoint pickup = userDoc['location.pickup'];
          pickupLocation = LatLng(pickup.latitude, pickup.longitude);
        }
        if (userDoc['location.drop'] != null) {
          GeoPoint drop = userDoc['location.drop'];
          dropLocation = LatLng(drop.latitude, drop.longitude);
        }
        if (userDoc['location.home.pickup'] != null) {
          GeoPoint homePickup = userDoc['location.home.pickup'];
          homePickupLoc = LatLng(homePickup.latitude, homePickup.longitude);
        }
        if (userDoc['location.home.drop'] != null) {
          GeoPoint homeDrop = userDoc['location.home.drop'];
          homeDropLoc = LatLng(homeDrop.latitude, homeDrop.longitude);
        }
        if (userDoc['location.work.pickup'] != null) {
          GeoPoint workPickup = userDoc['location.work.pickup'];
          workPickupLoc = LatLng(workPickup.latitude, workPickup.longitude);
        }
        if (userDoc['location.work.drop'] != null) {
          GeoPoint workDrop = userDoc['location.work.drop'];
          workDropLoc = LatLng(workDrop.latitude, workDrop.longitude);
        }
      });
    }
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
        if (isOrderComplete())
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => goToOrderSummary(context),
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  void goToOrderSummary(BuildContext context) async {
    if (!isOrderComplete()) {
      showError('Please complete the order details.');
      return;
    }

    // Calculate the end date (28 days from the pickup date)
    final DateTime endDate = selectedPickupDate!.add(const Duration(days: 28));

    // Navigate to OrderSummaryScreen and wait for the result
    final bool? isConfirmed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderSummaryScreen(
          selectedPlan: selectedPlan!,
          serviceType: serviceType!,
          selectedDays: selectedDays,
          timeSlots: timeSlots,
          selectedPickupDate: selectedPickupDate!,
          deliveryDate: deliveryDate!,
          endDate: endDate,
        ),
      ),
    );

    if (isConfirmed == true) {
      submitOrder();
    } else {
      showError('Order submission was cancelled.');
    }
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
                    const SizedBox(height: 2),
                    const Text('A monthly service for 28 days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
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
        if (selectedDays.isNotEmpty)
          Text(
            'Service Days: ${selectedDays.take(3).join(', ')}', // Only take the first 3 days
            style: const TextStyle(fontSize: 16),
          ),
        Text('Time Slots: ${timeSlots.join(', ')}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        const Divider(color: Colors.grey),

        // Show start date
        if (selectedPickupDate != null)
          Text(
            'Selected Pickup Date: ${DateFormat('MMMM dd, yyyy').format(selectedPickupDate!)}',
            style: const TextStyle(fontSize: 16),
          ),

        // Show delivery date (based on service type)
        if (deliveryDate != null)
          Text(
            'Delivery Date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate!)}',
            style: const TextStyle(fontSize: 16),
          ),

        // Show end date (28 days from pickup date)
        if (deliveryDate != null)
          Text(
            'End Date (28 days from start): ${DateFormat('MMMM dd, yyyy').format(selectedPickupDate!.add(const Duration(days: 28)))}',
            style: const TextStyle(fontSize: 16),
          ),

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

      // Calculate the delivery date based on service type
      DateTime? deliveryDate;
      if (serviceType == 'Pickup every 2 days') {
        deliveryDate = selectedPickupDate!.add(const Duration(days: 2)); // Delivery 2 days after pickup
      } else if (serviceType == 'Pickup every 3 days') {
        deliveryDate = selectedPickupDate!.add(const Duration(days: 3)); // Delivery 3 days after pickup
      } else {
        showError('Invalid service type.');
        return;
      }

      // Calculate the end date, which is 28 days from the selected start date (pickup date)
      DateTime endDate = selectedPickupDate!.add(const Duration(days: 28));

      // Ensure selectedDays only stores 3 days
      List<String> limitedSelectedDays = selectedDays.take(3).toList(); // Limit to 3 days

      // Order data to be submitted, including current pickup/drop and home/work locations inside the location tree
      Map<String, dynamic> orderData = {
        'createdAt': now,
        'updatedAt': now,
        'isActive': true,
        'startDate': Timestamp.fromDate(selectedPickupDate!), // Start date is the selected pickup date
        'endDate': Timestamp.fromDate(endDate), // End date is 28 days from the start date
        'serviceType': serviceType,
        'selectedDays': limitedSelectedDays, // Store only the first 3 selected days
        'timeSlots': timeSlots,
        'paymentDetails': {
          'amount': 100,
          'transactionId': "dummyTransaction123",
        },
        'services': planRef,
        'userId': userRef,
        'deliveryDate': Timestamp.fromDate(deliveryDate), // Store the calculated delivery date
        'location': {
          'pickup': GeoPoint(pickupLocation!.latitude, pickupLocation!.longitude),
          'drop': GeoPoint(dropLocation!.latitude, dropLocation!.longitude),
          'home': {
            'pickup': tempHomePickupLoc != null ? GeoPoint(tempHomePickupLoc!.latitude, tempHomePickupLoc!.longitude) : null,
            'drop': tempHomeDropLoc != null ? GeoPoint(tempHomeDropLoc!.latitude, tempHomeDropLoc!.longitude) : null,
          },
          'work': {
            'pickup': tempWorkPickupLoc != null ? GeoPoint(tempWorkPickupLoc!.latitude, tempWorkPickupLoc!.longitude) : null,
            'drop': tempWorkDropLoc != null ? GeoPoint(tempWorkDropLoc!.latitude, tempWorkDropLoc!.longitude) : null,
          }
        }
      };

      // Add the order data to Firestore
      await FirebaseFirestore.instance.collection('subscriptions').add(orderData);
      showSuccess('Order created successfully!');

      // Fetch user orders to display the subscription card
      fetchUserOrders();

      // Reset temporary values after order submission
      setState(() {
        selectedPlan = null;
        serviceType = null;
        pickupLocation = null;
        dropLocation = null;
        pickupController.clear();
        dropController.clear();
        deliveryDate = null;
        selectedPickupDate = null;
        isPickupConfirmed = false;
        isDropConfirmed = false;

        tempHomePickupLoc = null;
        tempHomeDropLoc = null;
        tempWorkPickupLoc = null;
        tempWorkDropLoc = null;
      });
    } catch (error) {
      showError('Failed to submit order. Please try again.');
    }
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
          GestureDetector(
            onPanDown: (_) {
              setState(() {
                _isMapInteracting = true; // Disable scrolling when interacting with the map
              });
            },
            onPanCancel: () {
              setState(() {
                _isMapInteracting = false; // Re-enable scrolling after interaction
              });
            },
            onPanEnd: (_) {
              setState(() {
                _isMapInteracting = false; // Re-enable scrolling when interaction ends
              });
            },
            child: SizedBox(
              height: 300,
              child: AbsorbPointer(
                absorbing: _isMapInteracting, // Absorb pointer events during interaction
                child: GoogleMap(
                  onMapCreated: (controller) => mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: pickupLocation ?? LatLng(17.4239, 78.4738), // Initial location
                    zoom: 14.0,
                  ),
                  markers: markers,
                  onTap: (position) {
                    _onMapTap(position, true); // Handle tapping to set pickup location
                  },
                  onCameraMove: (position) {
                    if (_isMapInteracting) {
                      // Update the pickup marker position
                      setState(() {
                        pickupLocation = position.target;
                        _updatePickupMarker(position.target);
                      });
                    }
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
                      _showSaveLocationDialog(isPickupLocation: true);
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
              _geocodeAddress(value, isPickupLocation: false); // Geocode drop location
              _handleNewDropLocation(); // Handle saving the new drop location
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
                target: dropLocation ?? LatLng(17.4239, 78.4738), // Initial location
                zoom: 14.0,
              ),
              markers: markers,
              onTap: (position) {
                _onMapTap(position, false); // Handle tapping to set drop location
              },
              onCameraMove: (position) {
                if (_isMapInteracting) {
                  // Update drop marker position
                  setState(() {
                    dropLocation = position.target;
                    _updateDropMarker(position.target);
                  });
                }
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
                      _handleNewDropLocation(); // Handle saving new drop location
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


  void _updatePickupMarker(LatLng newPosition) {
    markers.removeWhere((m) => m.markerId.value == 'pickup');
    markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: newPosition,
      draggable: true,
      onDragEnd: (newPos) {
        setState(() {
          pickupLocation = newPos; // Update the pickup location after dragging
          mapController?.animateCamera(CameraUpdate.newLatLng(newPos)); // Move camera with marker
        });
      },
    ));
  }

  void _updateDropMarker(LatLng newPosition) {
    markers.removeWhere((m) => m.markerId.value == 'drop');
    markers.add(Marker(
      markerId: const MarkerId('drop'),
      position: newPosition,
      draggable: true,
      onDragEnd: (newPos) {
        setState(() {
          dropLocation = newPos; // Update the drop location after dragging
          mapController?.animateCamera(CameraUpdate.newLatLng(newPos)); // Move camera with marker
        });
      },
    ));
  }


  void _onMapTap(LatLng position, bool isPickupLocation) {
    setState(() {
      if (isPickupLocation) {
        pickupLocation = position;
        markers.removeWhere((m) => m.markerId.value == 'pickup');
        markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLocation!,
          draggable: true,
          onDragEnd: (newPos) {
            setState(() {
              pickupLocation = newPos; // Update after dragging
            });
          },
        ));
        pickupController.text = '${pickupLocation!.latitude}, ${pickupLocation!.longitude}';
      } else {
        dropLocation = position;
        markers.removeWhere((m) => m.markerId.value == 'drop');
        markers.add(Marker(
          markerId: const MarkerId('drop'),
          position: dropLocation!,
          draggable: true,
          onDragEnd: (newPos) {
            setState(() {
              dropLocation = newPos; // Update after dragging
            });
          },
        ));
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

  void _handleNewDropLocation() {
    if (dropLocation != pickupLocation) {
      // Show a dialog asking to update the home/work drop location
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Save Drop Location'),
            content: const Text('You entered a different drop location. Would you like to save this as your Home or Work drop location?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();  // Close the dialog without saving
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _saveLocationAs('home', isPickupLocation: false);  // Save as home drop
                  Navigator.of(context).pop();  // Close the dialog
                },
                child: const Text('Home'),
              ),
              TextButton(
                onPressed: () {
                  _saveLocationAs('work', isPickupLocation: false);  // Save as work drop
                  Navigator.of(context).pop();  // Close the dialog
                },
                child: const Text('Work'),
              ),
            ],
          );
        },
      );
    }
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
          children: [
            if (userOrders.isNotEmpty) buildUserOrders(),
            if (userOrders.isEmpty) buildOrderPlacement(),
          ],
        ),
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

  Widget buildUserOrders() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: userOrders.length,
      itemBuilder: (context, index) {
        final order = userOrders[index];

        // Retrieve the deliveryDate and convert it from Timestamp to DateTime
        var deliveryDate = order['deliveryDate'];
        if (deliveryDate != null && deliveryDate is Timestamp) {
          deliveryDate = deliveryDate.toDate();
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Service Type: ${order['serviceType']}', style: const TextStyle(fontSize: 16)),

                // Display current pickup and drop locations
                if (order['pickupLoc'] != null)
                  Text('Pickup Location: LatLng(${order['pickupLoc'].latitude}, ${order['pickupLoc'].longitude})'),
                if (order['dropLoc'] != null)
                  Text('Drop Location: LatLng(${order['dropLoc'].latitude}, ${order['dropLoc'].longitude})'),

                // Display home pickup and drop locations if available
                if (order['homePickupLoc'] != null)
                  Text('Home Pickup Location: LatLng(${order['homePickupLoc'].latitude}, ${order['homePickupLoc'].longitude})'),
                if (order['homeDropLoc'] != null)
                  Text('Home Drop Location: LatLng(${order['homeDropLoc'].latitude}, ${order['homeDropLoc'].longitude})'),

                // Display work pickup and drop locations if available
                if (order['workPickupLoc'] != null)
                  Text('Work Pickup Location: LatLng(${order['workPickupLoc'].latitude}, ${order['workPickupLoc'].longitude})'),
                if (order['workDropLoc'] != null)
                  Text('Work Drop Location: LatLng(${order['workDropLoc'].latitude}, ${order['workDropLoc'].longitude})'),

                // Show start date
                Text('Start Date: ${DateFormat('MMMM dd, yyyy').format(order['startDate'])}'),

                // Show delivery date if it exists
                if (deliveryDate != null)
                  Text(
                    'Delivery Date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate)}',
                  ),

                // Show end date (stored in the database as 'endDate')
                Text('End Date: ${DateFormat('MMMM dd, yyyy').format(order['endDate'])}'),

                Text('Amount Paid: ₹${order['paymentDetails']['amount']}'),

                // Display the selected days
                if (order['selectedDays'] != null && order['selectedDays'].isNotEmpty)
                  Text('Selected Days: ${order['selectedDays'].join(', ')}', style: const TextStyle(fontSize: 16)),

                // Display the selected time slots
                if (order['timeSlots'] != null && order['timeSlots'].isNotEmpty)
                  Text('Time Slots: ${order['timeSlots'].join(', ')}', style: const TextStyle(fontSize: 16)),

                if (order['planName'] != null)
                  Text('Current Plan: ${order['planName']}', style: const TextStyle(fontSize: 16)),

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => showPlanUpgradeDialog(order['id']),
                        child: const Text('Upgrade Plan'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EditOrderScreen(subscriptionId: order['id']),
                          ),
                        );
                      },
                    )

                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
                Navigator.of(context, rootNavigator: true).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                _showSuccessModal(dialogContext);
                updateSubscriptionPlan(orderId, selectedPlanId);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Plan upgraded successfully!'),
          actions: [
            TextButton(
              onPressed: () {
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

      await FirebaseFirestore.instance.collection('subscriptions').doc(orderId).update({
        'services': planRef,
        'updatedAt': Timestamp.now(),
      });

      DocumentSnapshot planSnapshot = await planRef.get();
      String? updatedPlanName = planSnapshot.exists ? planSnapshot['name'] : 'No plan name';

      setState(() {
        for (var order in userOrders) {
          if (order['id'] == orderId) {
            order['planName'] = updatedPlanName;
          }
        }
      });

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
}