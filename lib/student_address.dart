import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Address {
  final String name;
  final String addrs;
  final String phone;

  const Address({
    required this.name,
    required this.addrs,
    required this.phone,
  });
}



final List<Address> addressList = const [
  Address( name: 'রহিম',    addrs: 'cumilla', phone: '363473463'),
  Address( name: 'করিম',   addrs:'rongpur',   phone:'9842354' ),
  Address( name: 'জামাল',   addrs: 'dinajpur',phone: '23175786'),
  Address( name: 'Nadim',  addrs: "sylhet",   phone: '2408465'),
];

Color getColorCode(Address a){
  int index = addressList.indexOf(a);
  return index % 2 == 0 ? Colors.cyan : Colors.brown.shade100;
}

class StudentAddress extends StatelessWidget {
  const StudentAddress({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Student Name')),
          DataColumn(label: Text('Address')),
          DataColumn(label: Text('Phone'))],

        rows: addressList.map((add){
          return DataRow(color: WidgetStateProperty.all(getColorCode(add)),cells: [
            DataCell(Text(add.name)),
            DataCell(Text(add.addrs.toString())),
            DataCell(Text(add.phone.toString())),
          ]);
        }).toList(),
      ),
    );
  }
}