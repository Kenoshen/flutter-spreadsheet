import 'package:flutter/material.dart';
import 'package:table_sticky_headers/table_sticky_headers.dart';

class StickyExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StickyHeadersTable(
      columnsLength: 15,
      rowsLength: 20,
      columnsTitleBuilder: (i) => SizedBox.fromSize(size: Size(100, 50), child: Padding(padding: EdgeInsets.all(10), child:TextFormField(initialValue: "$i",))),
      rowsTitleBuilder: (i) => SizedBox.fromSize(size: Size(100, 50), child: Padding(padding: EdgeInsets.all(10), child:TextFormField(initialValue: "$i",))),
      contentCellBuilder: (i, k) => SizedBox.fromSize(size: Size(100, 50), child: Padding(padding: EdgeInsets.all(10), child:TextFormField(initialValue: "$i,$k",))),
      legendCell: Text('Sticky Legend'),
      cellDimensions: CellDimensions(contentCellWidth: 100, contentCellHeight: 100, stickyLegendWidth: 100, stickyLegendHeight: 50),
    );
  }

}