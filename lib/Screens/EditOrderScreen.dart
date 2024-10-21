import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

import 'ScheduleScreen.dart';

class EditOrderScreen extends StatefulWidget {
  final String? subscriptionId;

  EditOrderScreen({this.subscriptionId});

  @override
  _EditOrderScreenState createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  String? selectedPlan;
  String? serviceType;
  DateTime? existingStartDate;
  String? currentServiceTypeInOrder;
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

  List<DateTime> daysOfWeek = [];

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
    if (widget.subscriptionId != null) {
      fetchSubscriptionDetails(widget.subscriptionId);
    }
    generateWeekDays();
  }

  void generateWeekDays() {
    DateTime today = DateTime.now();
    DateTime startOfWeek = today.subtract(Duration(days: today.weekday - DateTime.monday));

    daysOfWeek.clear();

    for (int i = 0; i < 6; i++) {
      DateTime day = startOfWeek.add(Duration(days: i));
      daysOfWeek.add(day);
    }

    setState(() {});
  }

  Future<void> fetchSubscriptionDetails(String? subscriptionId) async {
    if (subscriptionId == null) return;

    try {
      DocumentSnapshot subscriptionDoc = await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(subscriptionId)
          .get();

      DocumentSnapshot planDoc = await subscriptionDoc['services'].get();

      setState(() {
        selectedPlan = planDoc.id;
        serviceType = subscriptionDoc['serviceType'];
        currentServiceTypeInOrder = subscriptionDoc['serviceType'];
        selectedPickupDate = subscriptionDoc['startDate'].toDate();
        existingStartDate = subscriptionDoc['startDate'].toDate();
        deliveryDate = subscriptionDoc['endDate']?.toDate();
        pickupLocation = LatLng(subscriptionDoc['pickupLoc'].latitude, subscriptionDoc['pickupLoc'].longitude);
        dropLocation = LatLng(subscriptionDoc['dropLoc'].latitude, subscriptionDoc['dropLoc'].longitude);
        pickupController.text = '${pickupLocation!.latitude}, ${pickupLocation!.longitude}';
        dropController.text = '${dropLocation!.latitude}, ${dropLocation!.longitude}';

        selectedDays = List<String>.from(subscriptionDoc['selectedDays'] ?? []);
        timeSlots = List<String>.from(subscriptionDoc['timeSlots'] ?? []);

        isPickupConfirmed = true;
        isDropConfirmed = true;
      });
    } catch (error) {
      showError("Error fetching subscription details.");
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
        };
      }).toList();

      setState(() {
        plans = fetchedPlans;
      });
    } catch (error) {
      showError("Error fetching plans.");
    }
  }

  void handleDaySelection(DateTime day) {
    setState(() {
      selectedDays.clear(); // Clear previously selected days

      if (serviceType == 'Pickup every 2 days') {
        selectedPickupDate = day;

        DateTime nextDay = day;
        while (selectedDays.length < 3) {
          selectedDays.add(DateFormat('EEEE').format(nextDay));
          nextDay = addDaysSkippingSunday(nextDay, 2);
        }
      } else if (serviceType == 'Pickup every 3 days') {
        selectedPickupDate = day;

        DateTime nextDay1 = addDaysSkippingSunday(day, 3);
        DateTime nextDay2 = addDaysSkippingSunday(nextDay1, 3);

        selectedDays.add(DateFormat('EEEE').format(day));
        selectedDays.add(DateFormat('EEEE').format(nextDay1));
        selectedDays.add(DateFormat('EEEE').format(nextDay2));
      }

      // Calculate the delivery date based on the plan (skip Sundays)
      calculateDeliveryDate(day);
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

  void calculateDeliveryDate(DateTime pickupDate) {
    setState(() {
      if (serviceType == 'Pickup every 2 days') {
        deliveryDate = addDaysSkippingSunday(pickupDate, 2);
      } else if (serviceType == 'Pickup every 3 days') {
        deliveryDate = addDaysSkippingSunday(pickupDate, 3);
      }
    });
  }

  void handleServiceTypeChange(String newServiceType) {
    setState(() {
      serviceType = newServiceType;
      selectedDays.clear(); // Clear all selected days when the service type is switched
      selectedPickupDate = null; // Clear selected pickup date
      deliveryDate = null; // Clear the delivery date
      generateWeekDays(); // Regenerate the days to ensure fresh containers are visible
    });
  }


  Widget buildDaysSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          serviceType == 'Pickup every 2 days'
              ? 'Select Days for Pickup every 2 Days'
              : 'Select Days for Pickup every 3 Days',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: daysOfWeek.map((day) {
            final isSelected = selectedDays.contains(DateFormat('EEEE').format(day));
            final isExistingStartDate =
                existingStartDate != null && isSameDay(day, existingStartDate!) && serviceType == currentServiceTypeInOrder;

            return GestureDetector(
              onTap: isExistingStartDate
                  ? () {
                showWarningDialog('You cannot select the existing day in this plan.');
              }
                  : () => handleDaySelection(day),
              child: SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 3,
                height: 80,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isExistingStartDate
                        ? Colors.orange // Highlight existing start date in orange for current plan
                        : (isSelected ? Colors.blue : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isExistingStartDate ? Colors.orange : (isSelected ? Colors.blue : Colors.grey),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEEE').format(day),
                          style: TextStyle(
                            color: isExistingStartDate ? Colors.white : (isSelected ? Colors.white : Colors.black),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM').format(day),
                          style: TextStyle(
                            color: isExistingStartDate ? Colors.white : (isSelected ? Colors.white : Colors.black),
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

  bool isSameDay(DateTime day1, DateTime day2) {
    return day1.year == day2.year && day1.month == day2.month && day1.day == day2.day;
  }

  void showWarningDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Warning'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
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
        ),
        const SizedBox(height: 16),

        if (showPickupMap)
          Column(
            children: [
              // Display the map
              SizedBox(
                height: 300,
                child: GoogleMap(
                  onMapCreated: (controller) => mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: pickupLocation ?? LatLng(17.4239, 78.4738),
                    zoom: 14.0,
                  ),
                  markers: markers,
                  onTap: (position) {
                    _onMapTap(position, true);
                  },
                ),
              ),

              // Add Confirm and Cancel buttons below the map
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
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
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        ),
        const SizedBox(height: 16),

        if (showDropMap)
          Column(
            children: [
              // Display the map for drop location
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

              // Add Confirm and Cancel buttons below the map
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
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
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }


  Future<void> _geocodeAddress(String address, {required bool isPickupLocation}) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      LatLng position = LatLng(locations[0].latitude, locations[0].longitude);

      setState(() {
        if (isPickupLocation) {
          pickupLocation = position;
          markers.removeWhere((m) => m.markerId.value == 'pickup');
          markers.add(Marker(
            markerId: const MarkerId('pickup'),
            position: pickupLocation!,
            infoWindow: const InfoWindow(title: 'Pickup Location'),
          ));
          mapController?.animateCamera(CameraUpdate.newLatLng(pickupLocation!));
          showPickupMap = true; // Ensure map is shown after the location is set
        } else {
          dropLocation = position;
          markers.removeWhere((m) => m.markerId.value == 'drop');
          markers.add(Marker(
            markerId: const MarkerId('drop'),
            position: dropLocation!,
            infoWindow: const InfoWindow(title: 'Drop Location'),
          ));
          mapController?.animateCamera(CameraUpdate.newLatLng(dropLocation!));
          showDropMap = true; // Ensure drop location map is shown
        }
      });
    } catch (e) {
      showError("Error finding location. Please try again.");
    }
  }


  Widget buildOrderSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(color: Colors.grey),
        const SizedBox(height: 8),
        Text('Selected Plan: ${selectedPlan ?? 'None'}', style: const TextStyle(fontSize: 16)),
        Text('Service Type: ${serviceType ?? 'None'}', style: const TextStyle(fontSize: 16)),
        Text('Service Days: ${selectedDays.isNotEmpty ? selectedDays.join(', ') : 'None'}', style: const TextStyle(fontSize: 16)),
        Text('Time Slots: ${timeSlots.isNotEmpty ? timeSlots.join(', ') : 'None'}', style: const TextStyle(fontSize: 16)),
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
      ],
    );
  }

  Future<void> updateSubscription() async {
    try {
      if (pickupLocation == null || dropLocation == null) {
        showError('Please select both pickup and drop locations.');
        return;
      }

      String? subscriptionId = widget.subscriptionId;
      if (subscriptionId == null) {
        showError('Subscription ID is missing.');
        return;
      }

      DateTime now = DateTime.now();
      DocumentReference planRef = FirebaseFirestore.instance.collection('plans').doc(selectedPlan);

      // Prepare the data
      Map<String, dynamic> updatedData = {
        'updatedAt': now,
        'startDate': Timestamp.fromDate(selectedPickupDate!),
        'endDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
        'pickupLoc': GeoPoint(pickupLocation!.latitude, pickupLocation!.longitude),
        'dropLoc': GeoPoint(dropLocation!.latitude, dropLocation!.longitude),
        'serviceType': serviceType,
        'services': planRef,
        'selectedDays': selectedDays,
        'timeSlots': timeSlots,
      };

      // Update the subscription in Firebase
      await FirebaseFirestore.instance.collection('subscriptions').doc(subscriptionId).update(updatedData);

      // Show success dialog
      showSuccess('Order updated successfully!');

    } catch (error) {
      // Only show error if something goes wrong
      showError('Failed to update subscription. Please try again.');
    }
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
          TextButton(
            onPressed: () {
              // Navigate to the ScheduleScreen and prevent back navigation
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => ScheduleScreen()),
                    (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Order'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: buildOrderEditForm(),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: updateSubscription,
                child: const Text('Update Order'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOrderEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildPlanSelection(),
        buildServiceTypeSelection(),
        buildDaysSelection(),
        buildTimeSlotsSelection(),
        buildGoogleMapSection(),
        buildOrderSummary(),
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
                onTap: () => setState(() => serviceType = type),
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
              child: SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 3,  // Ensure 3 items per row
                height: 80,  // Match the day container height
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? Colors.blue : Colors.grey, width: 2),
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
              ),
            );
          }).toList(),
        ),
      ],
    );
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
}
