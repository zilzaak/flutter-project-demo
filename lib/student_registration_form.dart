import 'package:flutter/material.dart';
import 'student_details_page.dart';

TextEditingController nameController = TextEditingController();
TextEditingController rollController = TextEditingController();
TextEditingController regController = TextEditingController();
TextEditingController phoneController = TextEditingController();
TextEditingController addressController = TextEditingController();

class StudentInfo{
  final String studentName;
  final String roll;
  final String regNo;
  final String address;
  final String gpa;

  const StudentInfo({
    required this.studentName,
    required this.roll,
    required this.regNo,
    required this.address,
    required this.gpa
});
}

List<StudentInfo> studentList = [];



class StudentRegistrationForm extends StatefulWidget {
  const StudentRegistrationForm({super.key});
  @override
  State<StudentRegistrationForm> createState() => _StudentRegistrationFormState();
}


class _StudentRegistrationFormState extends State<StudentRegistrationForm> {


  Widget _buildStudentTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Roll')),
          DataColumn(label: Text('Reg No')),
          DataColumn(label: Text('Address')),
          DataColumn(label: Text('GPA')),
          DataColumn(label: Text('Action')),
        ],
        rows: studentList.asMap().entries.map((entry) {
          int index = entry.key;
          StudentInfo student = entry.value;
          return DataRow(
            color: WidgetStateProperty.all(
              index % 2 == 0 ? Colors.grey.shade200 : Colors.blue.shade100,
            ),
            cells: [
              DataCell(Text(student.studentName)),
              DataCell(Text(student.roll)),
              DataCell(Text(student.regNo)),
              DataCell(Text(student.address)),
              DataCell(Text(student.gpa)),
              DataCell(IconButton(icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => deleteStudent(index), tooltip: 'Delete Student'))
            ],
          );
        }).toList(),
      ),
    );
  }


  void _addStudent() {
    print('now we will add data in the list ');
    String name = nameController.text;
    String roll = rollController.text;
    String reg = regController.text;
    String address = phoneController.text;
    String gpa = addressController.text;

    if(name.trim().isEmpty || roll.trim().isEmpty || reg.trim().isEmpty || address.trim().isEmpty || gpa.trim().isEmpty ){
      showAlert(context, 'Name , roll , reg , address , gpa must not be blank , provide value ');
      return;
    }

    // Create new student object
    StudentInfo newStudent = StudentInfo(studentName: name, roll: roll, regNo: reg, address: address, gpa: gpa);
    setState(() {
      studentList.add(newStudent);
    });

   studentList.forEach((si) {
      print('Name: ${si.studentName}, Roll: ${si.roll}, Reg: ${si.regNo}, GPA: ${si.gpa}');
    });

    nameController.clear();
    rollController.clear();
    regController.clear();
    phoneController.clear();
    addressController.clear();
  }


  void deleteStudent(int index){
    StudentInfo newStudent = studentList[index];
    setState(() {
      studentList.remove(newStudent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Registration'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
        body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Student Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: rollController,
              decoration: InputDecoration(
                labelText: 'Roll Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            SizedBox(height: 15),
            TextField(
              controller: regController,
              decoration: InputDecoration(
                labelText: 'Registration Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            SizedBox(height: 15),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            SizedBox(height: 15),

            TextField(
              controller: addressController,
              decoration: InputDecoration(
                labelText: 'GPA',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 30),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: Text('GO BACK'),
          ),
            SizedBox(height: 15),
            ElevatedButton(
               onPressed: () {
                _addStudent();
              },
              child: Text('SUBMIT'),
            ),
            SizedBox(height:15,),
            _buildStudentTable(),
          ],
        ),
      ),
    );
  }

}


void showAlert(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Alert'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      );
    },
  );
}


