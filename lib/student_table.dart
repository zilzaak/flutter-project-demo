import 'package:flutter/material.dart';

class Student {
  final int sl;
  final String name;
  final int roll;
  final double gpa;

  const Student({
    required this.sl,
    required this.name,
    required this.roll,
    required this.gpa,
  });
}

final List<Student> students = const [
  Student(sl: 1, name: 'রহিম', roll: 101, gpa: 3.80),
  Student(sl: 2, name: 'করিম', roll: 102, gpa: 3.50),
  Student(sl: 3, name: 'জামাল', roll: 103, gpa: 3.90),
  Student(sl: 4, name: 'Nadim', roll: 104, gpa: 3.25),
];

Color _getRowColor(Student st) {
  int index = students.indexOf(st);
  return index % 2 == 0 ? Colors.grey.shade200 : Colors.blue.shade100;
}


class StudentTable extends StatelessWidget {
  const StudentTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('SL No')),
          DataColumn(label: Text('Student Name')),
          DataColumn(label: Text('Roll')),
          DataColumn(label: Text('GPA')),
        ],
        rows: students.map((student) {
          return DataRow(color: WidgetStateProperty.all(_getRowColor(student)),cells: [
            DataCell(Text(student.sl.toString())),
            DataCell(Text(student.name)),
            DataCell(Text(student.roll.toString())),
            DataCell(Text(student.gpa.toString())),
          ]);
        }).toList(),
      ),
    );
  }



}