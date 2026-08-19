import 'package:flutter/material.dart';

class StudentDetailsPage extends StatelessWidget {
  final String name;
  final String roll;
  final String reg;
  final String phone;
  final String address;

  const StudentDetailsPage({
    super.key,
    required this.name,
    required this.roll,
    required this.reg,
    required this.phone,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Details'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✅ Registration Successful!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 30),
            Text('Name: $name', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Roll: $roll', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Registration: $reg', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Phone: $phone', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Address: $address', style: TextStyle(fontSize: 18)),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('BACK TO FORM'),
            ),
          ],
        ),
      ),
    );
  }
}