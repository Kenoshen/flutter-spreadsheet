import 'package:flutter/material.dart';
import 'package:spreadsheet/reorderable.dart';
import 'package:spreadsheet/spreadsheet.dart';
import 'package:spreadsheet/sticky.dart';
import 'package:table_sticky_headers/table_sticky_headers.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spreadsheet',
      home: MyHomePage(title: 'Spreadsheet Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage({Key key, this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      // body: StickyExample(),
      // body: ReorderableExample(),
      body: SpreadsheetExample(),
    );
  }
}

class SpreadsheetExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var w = 100.0;
    var h = 100.0;
    var diff = 30.0;
    var padding = 20.0;
    return Spreadsheet(
      frozenColumns: 1,
      frozenRows: 1,
      padding: EdgeInsets.all(padding),
      cells: [
        [
          SpreadsheetCell(child: ColoredBox(color: Colors.blue), width: w, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.red), width: w - diff, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.green), width: w + diff, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.yellow), width: w, height: h - diff),
          SpreadsheetCell(child: ColoredBox(color: Colors.purple), width: w, height: h + diff),
          SpreadsheetCell(child: ColoredBox(color: Colors.orange), width: w, height: h + diff),
        ],
        [
          SpreadsheetCell(child: ColoredBox(color: Colors.purple), width: w + diff, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.blue), width: w, height: h + diff),
          SpreadsheetCell(child: ColoredBox(color: Colors.red), width: w, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.green), width: w - diff, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.yellow), width: w, height: h - diff),
          SpreadsheetCell(child: ColoredBox(color: Colors.orange), width: w, height: h + diff),
        ],
        [
          SpreadsheetCell(child: ColoredBox(color: Colors.yellow), width: w, height: h + diff),
          SpreadsheetCell(child: ColoredBox(color: Colors.purple), width: w, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.blue), width: w, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.red), width: w, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.green), width: w, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.orange), width: w, height: h + diff),
        ],
        [
          SpreadsheetCell(child: ColoredBox(color: Colors.green), width: w, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.orange), width: w, height: h + diff),
          SpreadsheetCell(child: ColoredBox(color: Colors.red), width: w, height: h - diff),
          SpreadsheetCell(child: ColoredBox(color: Colors.yellow), width: w, height: h + diff),
          SpreadsheetCell(child: ColoredBox(color: Colors.purple), width: w, height: h),
          SpreadsheetCell(child: ColoredBox(color: Colors.blue), width: w + diff, height: h - diff),
        ],
      ],
    );
  }
}
