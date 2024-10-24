import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlansPageScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Plans'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchPlans(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('An error occurred: ${snapshot.error}'));
          }

          final plans = snapshot.data ?? [];

          if (plans.isEmpty) {
            return Center(
              child: Text('No plans available'),
            );
          }

          return ListView.builder(
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return PlanCard(plan: plan);
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> fetchPlans() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('plans').get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'],
          'price': data['price'],
          'description': data['description'] ?? 'No description available',
        };
      }).toList();
    } catch (e) {
      throw e;
    }
  }
}

class PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;

  const PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(10),
      elevation: 5,
      child: ListTile(
        title: Text(plan['name']),
        subtitle: Text('Price: ₹${plan['price']}'),
        trailing: Icon(Icons.info_outline),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlanDetailsPage(plan: plan),
            ),
          );
        },
      ),
    );
  }
}

class PlanDetailsPage extends StatelessWidget {
  final Map<String, dynamic> plan;

  const PlanDetailsPage({required this.plan});

  @override
  Widget build(BuildContext context) {
    final planName = plan['name'] ?? 'Unknown Plan';
    final planPrice = plan['price'] ?? 'N/A';
    final planDescription = plan['description'] ?? 'No description available';
    final planFeatures = plan['features'] ?? [];
    final planTerms = plan['terms'] ?? 'No terms and conditions provided';

    return Scaffold(
      appBar: AppBar(
        title: Text('$planName Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('Plan Name: $planName', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Price: ₹$planPrice', style: TextStyle(fontSize: 18)),
            SizedBox(height: 16),
            Text('Description:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(planDescription, style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            if (planFeatures.isNotEmpty) ...[
              Text('Features:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ...planFeatures.map<Widget>((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.check, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(child: Text(feature, style: TextStyle(fontSize: 16))),
                  ],
                ),
              )),
            ],
            SizedBox(height: 16),
            Text('Terms & Conditions:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(planTerms, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
