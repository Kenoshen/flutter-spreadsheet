import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Spreadsheet extends StatefulWidget {
  final List<List<SpreadsheetCell>> cells;
  final int frozenRows;
  final int frozenColumns;
  final EdgeInsets padding;

  Spreadsheet({@required this.cells, this.frozenRows = 0, this.frozenColumns = 0, this.padding = EdgeInsets.zero})
      : assert(_checkNotEmpty(cells), "Cells cannot be empty or null"),
        assert(_checkAllColumnsAreEqualSize(cells), "Cell columns must be equal in size");

  static bool _checkNotEmpty(List<List<SpreadsheetCell>> cells) {
    return cells != null && cells.length > 0;
  }

  static bool _checkAllColumnsAreEqualSize(List<List<SpreadsheetCell>> cells) {
    int len = -1;
    for (List<SpreadsheetCell> column in cells) {
      if (column == null) return false;
      if (len == -1) {
        len = column.length;
      } else if (len != column.length) return false;
    }
    return true;
  }

  @override
  _SpreadsheetState createState() => _SpreadsheetState();
}

class _SpreadsheetState extends State<Spreadsheet> {
  List<double> columnWidths;
  List<double> rowHeights;
  double totalWidth;
  double totalHeight;
  double frozenColumnWidth;
  double frozenRowHeight;
  List<double> columnPositions;
  List<double> rowPositions;
  int totalCells;
  int columnLength;
  List<_PositionedCell> bodyCells;
  List<_PositionedCell> frozenCornerCells;
  List<_PositionedCell> frozenColumnCells;
  List<_PositionedCell> frozenRowCells;

  ScrollController _verticalTitleController;
  ScrollController _verticalBodyController;
  ScrollController _horizontalBodyController;
  ScrollController _horizontalTitleController;
  _SyncScrollController _verticalSyncController;
  _SyncScrollController _horizontalSyncController;

  @override
  void initState() {
    super.initState();
    columnWidths = _calculateWidths(widget.cells);
    rowHeights = _calculateHeights(widget.cells);
    totalWidth = columnWidths.reduce((value, element) => value + element);
    totalHeight = rowHeights.reduce((value, element) => value + element);
    columnPositions = _calculatePositions(columnWidths);
    rowPositions = _calculatePositions(rowHeights);
    totalCells = widget.cells.length * widget.cells[0].length;
    frozenColumnWidth = widget.frozenColumns > 0 ? columnWidths.sublist(0, widget.frozenColumns).reduce((value, element) => value + element) : 0.0;
    frozenRowHeight = widget.frozenRows > 0 ? rowHeights.sublist(0, widget.frozenRows).reduce((value, element) => value + element) : 0.0;
    columnLength = widget.cells[0].length;
    _buildPositionedCells();

    _verticalTitleController = ScrollController();
    _verticalBodyController = ScrollController();
    _horizontalBodyController = ScrollController();
    _horizontalTitleController = ScrollController();
    _verticalSyncController = _SyncScrollController([_verticalTitleController, _verticalBodyController]);
    _horizontalSyncController = _SyncScrollController([_horizontalTitleController, _horizontalBodyController]);
  }

  @override
  void dispose() {
    super.dispose();
    _verticalSyncController.dispose();
    _horizontalSyncController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var frozenCorners = ConstrainedBox(constraints: BoxConstraints(maxWidth: frozenColumnWidth, maxHeight: frozenRowHeight), child: Stack(children: _wrapCells(frozenCornerCells)));
    var frozenColumns = ConstrainedBox(constraints: BoxConstraints(maxWidth: frozenColumnWidth, maxHeight: totalHeight), child: Stack(children: _wrapCells(frozenColumnCells)));
    var frozenRows = ConstrainedBox(constraints: BoxConstraints(maxWidth: totalWidth, maxHeight: frozenRowHeight), child: Stack(children: _wrapCells(frozenRowCells)));
    var body = ConstrainedBox(constraints: BoxConstraints(maxWidth: totalWidth, maxHeight: totalHeight), child: Stack(children: _wrapCells(bodyCells)));
    const physics = ClampingScrollPhysics();
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            // STICKY LEGEND
            frozenCorners,
            // STICKY ROW
            Expanded(
              child: NotificationListener<ScrollNotification>(
                child: SingleChildScrollView(
                  physics: physics,
                  scrollDirection: Axis.horizontal,
                  child: frozenRows,
                  controller: _horizontalTitleController,
                ),
                onNotification: (ScrollNotification notification) {
                  _horizontalSyncController.processNotification(notification, _horizontalTitleController);
                  return true;
                },
              ),
            )
          ],
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // STICKY COLUMN
              NotificationListener<ScrollNotification>(
                child: SingleChildScrollView(
                  physics: physics,
                  child: frozenColumns,
                  controller: _verticalTitleController,
                ),
                onNotification: (ScrollNotification notification) {
                  _verticalSyncController.processNotification(notification, _verticalTitleController);
                  return true;
                },
              ),
              // CONTENT
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    _horizontalSyncController.processNotification(notification, _horizontalBodyController);
                    return true;
                  },
                  child: SingleChildScrollView(
                    physics: physics,
                    scrollDirection: Axis.horizontal,
                    controller: _horizontalBodyController,
                    child: NotificationListener<ScrollNotification>(
                      child: SingleChildScrollView(
                          physics: physics,
                          controller: _verticalBodyController,
                          child: Column(
                            children: [body],
                          )),
                      onNotification: (ScrollNotification notification) {
                        _verticalSyncController.processNotification(notification, _verticalBodyController);
                        return true;
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _wrapCells(List<_PositionedCell> cells) {
    return cells.map(_wrapCell).toList();
  }

  Widget _wrapCell(_PositionedCell cell) {
    return Positioned(
      left: cell.x,
      top: cell.y,
      width: cell.width,
      height: cell.height,
      child: Align(
        alignment: cell.alignment,
        child: cell.cell,
      ),
    );
  }

  void _buildPositionedCells() {
    bodyCells = [];
    frozenCornerCells = [];
    frozenColumnCells = [];
    frozenRowCells = [];
    for (int x = 0; x < widget.cells.length; x++) {
      var column = widget.cells[x];
      var width = columnWidths[x];
      double xPos = columnPositions[x];
      for (int y = 0; y < column.length; y++) {
        SpreadsheetCell cell = column[y];
        var height = rowHeights[y];
        double yPos = rowPositions[y];
        Alignment align;
        if (x == 0 && y == 0)
          align = Alignment.bottomRight;
        else if (x == 0)
          align = Alignment.centerRight;
        else if (y == 0)
          align = Alignment.bottomCenter;
        else
          align = Alignment.center;

        var isFrozCol = x < widget.frozenColumns;
        var isFrozRow = y < widget.frozenRows;
        var isCorner = !isFrozCol && !isFrozRow;
        var pos = _PositionedCell(xPos - (isFrozRow || !isCorner ? frozenColumnWidth : 0.0), yPos - (isFrozCol || !isCorner ? frozenRowHeight : 0.0), width, height, align, cell);
        if (isFrozCol && isFrozRow)
          frozenCornerCells.add(pos);
        else if (isFrozCol)
          frozenColumnCells.add(pos);
        else if (isFrozRow)
          frozenRowCells.add(pos);
        else
          bodyCells.add(pos);
      }
    }
  }

  static List<double> _calculateWidths(List<List<SpreadsheetCell>> cells) {
    List<double> widths = List.filled(cells.length, 0.0);
    for (var i = 0; i < cells.length; i++) {
      var column = cells[i];
      double width = 0;
      for (var cell in column) {
        if (cell.width > width) {
          width = cell.width;
        }
      }
      widths[i] = width;
    }
    return widths;
  }

  static List<double> _calculateHeights(List<List<SpreadsheetCell>> cells) {
    List<double> heights = List.filled(cells[0].length, 0.0);
    for (var x = 0; x < cells.length; x++) {
      var column = cells[x];
      for (var y = 0; y < cells[x].length; y++) {
        var cell = column[y];
        if (x == 0)
          heights[y] = cell.height;
        else if (cell.height > heights[y]) heights[y] = cell.height;
      }
    }
    return heights;
  }

  static List<double> _calculatePositions(List<double> sizes) {
    List<double> positions = List.filled(sizes.length, 0.0);
    for (var i = 0; i < sizes.length; i++) {
      if (i == 0) {
        positions[i] = 0;
      } else {
        positions[i] = positions[i - 1] + sizes[i - 1];
      }
    }
    return positions;
  }
}

class _PositionedCell {
  final double x;
  final double y;
  final double width;
  final double height;
  final Alignment alignment;
  final SpreadsheetCell cell;

  _PositionedCell(this.x, this.y, this.width, this.height, this.alignment, this.cell);
}

class SpreadsheetCell extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  SpreadsheetCell({
    @required this.width,
    @required this.height,
    @required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      child: child,
      size: Size(width, height),
    );
  }
}

/// SyncScrollController keeps scroll controllers in sync.
class _SyncScrollController {
  _SyncScrollController(List<ScrollController> controllers) {
    controllers.forEach((controller) => _registeredScrollControllers.add(controller));
  }

  final List<ScrollController> _registeredScrollControllers = [];

  ScrollController _scrollingController;
  bool _scrollingActive = false;

  processNotification(ScrollNotification notification, ScrollController sender) {
    if (notification is ScrollStartNotification && !_scrollingActive) {
      _scrollingController = sender;
      _scrollingActive = true;
      return;
    }

    if (identical(sender, _scrollingController) && _scrollingActive) {
      if (notification is ScrollEndNotification) {
        _scrollingController = null;
        _scrollingActive = false;
        return;
      }

      if (notification is ScrollUpdateNotification) {
        for (ScrollController controller in _registeredScrollControllers) {
          if (identical(_scrollingController, controller)) continue;
          controller.jumpTo(_scrollingController.offset);
        }
      }
    }
  }

  void dispose() {
    for (ScrollController controller in _registeredScrollControllers) {
      controller.dispose();
    }
  }
}
