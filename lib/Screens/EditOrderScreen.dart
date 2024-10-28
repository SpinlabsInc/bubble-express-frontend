import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

import '../main.dart';
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
  LatLng? homePickupLoc;
  LatLng? homeDropLoc;
  LatLng? workPickupLoc;
  LatLng? workDropLoc;
  LatLng? tempHomePickupLoc;
  LatLng? tempHomeDropLoc;
  LatLng? tempWorkPickupLoc;
  LatLng? tempWorkDropLoc;
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
  DateTime? endDate;
  DateTime? selectedPickupDate;
  List<Map<String, dynamic>> plans = [];

  bool isPickupConfirmed = false;
  bool isDropConfirmed = false;
  bool showPickupMap = false;
  bool showDropMap = false;
  bool isHomeLocationUpdated = false;
  bool isWorkLocationUpdated = false;

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
    int currentWeekday = today.weekday;

    daysOfWeek.clear();

    // Loop through Monday to Saturday
    for (int i = 1; i <= 6; i++) {
      DateTime day;

      if (i < currentWeekday) {
        // For past days (Monday to today), shift them to the next week
        day = today.add(Duration(days: (i - currentWeekday + 7)));
      } else {
        // For today and future days, display this week's dates
        day = today.add(Duration(days: (i - currentWeekday)));
      }

      daysOfWeek.add(day); // Add calculated day to list
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

      // Fetch the locations from the `location` field
      Map<String, dynamic> locationData = subscriptionDoc['location'] ?? {};

      setState(() {
        selectedPlan = planDoc.id;
        serviceType = subscriptionDoc['serviceType'];
        currentServiceTypeInOrder = subscriptionDoc['serviceType'];
        selectedPickupDate = subscriptionDoc['startDate'].toDate();
        existingStartDate = subscriptionDoc['startDate'].toDate();
        deliveryDate = subscriptionDoc['deliveryDate']?.toDate();
        endDate = subscriptionDoc['endDate']?.toDate();

        // Fetch pickup and drop locations from location data
        pickupLocation = locationData['pickup'] != null
            ? LatLng(locationData['pickup'].latitude, locationData['pickup'].longitude)
            : null;
        dropLocation = locationData['drop'] != null
            ? LatLng(locationData['drop'].latitude, locationData['drop'].longitude)
            : null;

        // Set the text controllers
        pickupController.text = pickupLocation != null
            ? '${pickupLocation!.latitude}, ${pickupLocation!.longitude}'
            : '';
        dropController.text = dropLocation != null
            ? '${dropLocation!.latitude}, ${dropLocation!.longitude}'
            : '';

        // Fetch home and work locations
        LatLng? homePickupLoc = locationData['home']?['pickup'] != null
            ? LatLng(locationData['home']['pickup'].latitude, locationData['home']['pickup'].longitude)
            : null;
        LatLng? homeDropLoc = locationData['home']?['drop'] != null
            ? LatLng(locationData['home']['drop'].latitude, locationData['home']['drop'].longitude)
            : null;

        LatLng? workPickupLoc = locationData['work']?['pickup'] != null
            ? LatLng(locationData['work']['pickup'].latitude, locationData['work']['pickup'].longitude)
            : null;
        LatLng? workDropLoc = locationData['work']?['drop'] != null
            ? LatLng(locationData['work']['drop'].latitude, locationData['work']['drop'].longitude)
            : null;

        // Update selected days and time slots
        selectedDays = List<String>.from(subscriptionDoc['selectedDays'] ?? []);
        timeSlots = List<String>.from(subscriptionDoc['timeSlots'] ?? []);

        isPickupConfirmed = pickupLocation != null;
        isDropConfirmed = dropLocation != null;

        // If the pickup location is fetched, update the camera to the location and show the map
        if (pickupLocation != null) {
          showPickupMap = true;
          mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: pickupLocation!,
                zoom: 14.0,
              ),
            ),
          );

          markers.add(
            Marker(
              markerId: const MarkerId('pickup'),
              position: pickupLocation!,
              infoWindow: const InfoWindow(title: 'Pickup Location'),
            ),
          );
        }
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
                          // Use fixed labels: Monday to Saturday
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
                          // Display the actual date
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
              // Display the map for pickup location
              SizedBox(
                height: 300,
                child: GoogleMap(
                  onMapCreated: (controller) => mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: pickupLocation ?? LatLng(17.4239, 78.4738),  // Default location
                    zoom: 14.0,
                  ),
                  markers: markers,
                  onTap: (position) {
                    _onMapTap(position, true);  // Handle map tap for pickup location
                  },
                ),
              ),
              // Confirm and Cancel buttons below the map
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            isPickupConfirmed = true;
                            showPickupMap = false;
                            dropController.text = pickupController.text;  // Automatically assign pickup location to drop location
                            dropLocation = pickupLocation;
                          });

                          // Ask if the user wants to save the pickup location as home or work
                          await _showSaveLocationDialog(isPickupLocation: true);
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
                    _onMapTap(position, false);  // Handle map tap for drop location
                  },
                ),
              ),

              // Confirm and Cancel buttons below the map
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            isDropConfirmed = true;
                            showDropMap = false;
                          });

                          // Ask if the user wants to save the drop location as home or work
                          await _showSaveLocationDialog(isPickupLocation: false);
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
            'Estimated Delivery Date: ${DateFormat('MMMM dd, yyyy').format(deliveryDate!)}', // Show deliveryDate here
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
      // Check if pickup and drop locations are valid
      if (pickupLocation == null || dropLocation == null) {
        showError('Please select both pickup and drop locations.');
        return;
      }

      // Ensure that the subscription ID is not null
      String? subscriptionId = widget.subscriptionId;
      if (subscriptionId == null) {
        showError('Subscription ID is missing.');
        return;
      }

      // Ensure selectedPickupDate is not null
      if (selectedPickupDate == null) {
        showError('Please select a pickup date.');
        return;
      }

      DateTime now = DateTime.now();
      DocumentReference planRef = FirebaseFirestore.instance.collection('plans').doc(selectedPlan);

      // Create the initial data structure with fields that always get updated
      Map<String, dynamic> updatedData = {
        'updatedAt': now,
        'startDate': Timestamp.fromDate(selectedPickupDate!),
        'deliveryDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
        'serviceType': serviceType,
        'services': planRef,
        'selectedDays': selectedDays,
        'timeSlots': timeSlots,
      };

      // Fetch the current subscription data from Firestore
      DocumentSnapshot subscriptionSnapshot = await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(subscriptionId)
          .get();

      // Extract existing location data if available
      Map<String, dynamic> existingLocationData =
          subscriptionSnapshot.get('location') as Map<String, dynamic>? ?? {};

      // Ensure the location data is structured properly
      Map<String, dynamic> locationData = existingLocationData.isNotEmpty ? Map.from(existingLocationData) : {};

      // Only update pickup if it has changed
      if (pickupLocation != null && GeoPoint(pickupLocation!.latitude, pickupLocation!.longitude) != existingLocationData['pickup']) {
        locationData['pickup'] = GeoPoint(pickupLocation!.latitude, pickupLocation!.longitude);
      }

      // Only update drop if it has changed
      if (dropLocation != null && GeoPoint(dropLocation!.latitude, dropLocation!.longitude) != existingLocationData['drop']) {
        locationData['drop'] = GeoPoint(dropLocation!.latitude, dropLocation!.longitude);
      }

      // Only update the location field if any of the location data was modified
      if (locationData.isNotEmpty) {
        updatedData['location'] = locationData;
      }

      // Update the subscription in Firestore
      await FirebaseFirestore.instance.collection('subscriptions').doc(subscriptionId).update(updatedData);

      // Fetch user info for the notification
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Prepare the notification data
        Map<String, dynamic> notificationData = {
          'createdAt': Timestamp.now(),
          'data': 'Plan Update',
          'isRead': false,
          'message': 'Your plan has been successfully updated.',
          'title': 'Plan Update Successful',
          'userId': FirebaseFirestore.instance.collection('users').doc(user.uid),  // Reference to user document
        };

        // Add the notification to the 'notifications' collection
        await FirebaseFirestore.instance.collection('notifications').add(notificationData);
      }

      // Show success dialog
      showSuccess('Order updated successfully!');
    } catch (error) {
      print("Error updating subscription: $error");  // Log any errors to the console
      showError('Failed to update subscription. Please try again.');
    }
  }


  Future<void> _showSaveLocationDialog({required bool isPickupLocation}) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isPickupLocation ? 'Save Pickup Location' : 'Save Drop Location'),
          content: const Text('Would you like to save this location as your Home or Work location?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();  // Close the dialog without saving
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _saveLocationAs('home', isPickupLocation: isPickupLocation);  // Save as Home
                Navigator.of(context).pop();  // Close the dialog
              },
              child: const Text('Save as Home'),
            ),
            TextButton(
              onPressed: () {
                _saveLocationAs('work', isPickupLocation: isPickupLocation);  // Save as Work
                Navigator.of(context).pop();  // Close the dialog
              },
              child: const Text('Save as Work'),
            ),
          ],
        );
      },
    );
  }

  void _saveLocationAs(String type, {required bool isPickupLocation}) {
    setState(() {
      if (type == 'home') {
        isHomeLocationUpdated = true;  // Mark home location as updated
        if (isPickupLocation) {
          tempHomePickupLoc = pickupLocation;  // Save pickup location for home
          tempHomeDropLoc = pickupLocation;    // Automatically set drop location same as pickup for home
          dropController.text = pickupController.text;
        } else {
          tempHomeDropLoc = dropLocation;      // Save drop location for home
        }
      } else if (type == 'work') {
        isWorkLocationUpdated = true;  // Mark work location as updated
        if (isPickupLocation) {
          tempWorkPickupLoc = pickupLocation;  // Save pickup location for work
          tempWorkDropLoc = pickupLocation;    // Automatically set drop location same as pickup for work
          dropController.text = pickupController.text;
        } else {
          tempWorkDropLoc = dropLocation;      // Save drop location for work
        }
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

  void showSuccess(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              // Navigate back to MainScreen and set initialIndex to 1 (for ScheduleScreen)
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => MainScreen(initialIndex: 1),  // Set the tab index to ScheduleScreen
                ),
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

        // Include both Google Map for Pickup and Drop Location Sections
        buildGoogleMapSection(),  // For Pickup Location
        buildDropLocationSection(),  // For Drop Location

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