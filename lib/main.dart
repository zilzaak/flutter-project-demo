import 'package:flutter/material.dart';
import 'package:my_demo_project/student_address.dart';
import 'package:my_demo_project/student_registration_form.dart';
import 'package:my_demo_project/student_table.dart';

int _counter = 0;
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo Edited',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
        ),
         ),
        home: const MyHomePage(title: 'Flutter heading Edited',description: "This is trial of flutter",),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final String description;
  const MyHomePage({super.key, required this.title,required this.description});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  void increaseByOne() {
    setState(() { _counter=_counter+1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: Text(widget.description),
      ),
      body:SingleChildScrollView(
       child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Pushed the button for :'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 5),
            // Registration Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StudentRegistrationForm(),
                  ),
                );
              },
              child: const Text('GO TO REGISTRATION'),
            ),
            const StudentTable(),
            const StudentAddress()
          ],
        ),
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: increaseByOne,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}