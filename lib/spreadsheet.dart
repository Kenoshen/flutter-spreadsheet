import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Spreadsheet extends StatefulWidget {
  final List<List<SpreadsheetCell>> cells;
  final int frozenRows;
  final int frozenColumns;
  final EdgeInsets padding;
  final BorderSide border;
  final bool outerBorder;
  final Color frozenRowsColor;
  final bool striped;
  final Color stripeColor;

  Spreadsheet({
    @required this.cells,
    this.frozenRows = 0,
    this.frozenColumns = 0,
    this.padding = EdgeInsets.zero,
    this.border = BorderSide.none,
    this.outerBorder = false,
    this.frozenRowsColor,
    this.striped = false,
    this.stripeColor = Colors.grey,
  })  : assert(_checkNotEmpty(cells), "Cells cannot be empty or null"),
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

class _SpreadsheetState extends State<Spreadsheet> with TickerProviderStateMixin<Spreadsheet> {
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

  AnimationController _entranceController;
  AnimationController _ghostController;
  static const Duration _animationDuration = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _init();
    _verticalTitleController = ScrollController();
    _verticalBodyController = ScrollController();
    _horizontalBodyController = ScrollController();
    _horizontalTitleController = ScrollController();
    _verticalSyncController = _SyncScrollController([_verticalTitleController, _verticalBodyController]);
    _horizontalSyncController = _SyncScrollController([_horizontalTitleController, _horizontalBodyController]);
    _entranceController = AnimationController(value: 1.0, vsync: this, duration: _animationDuration);
    _ghostController = AnimationController(value: 0, vsync: this, duration: _animationDuration);
  }

  void _init() {
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
  }

  @override
  void didUpdateWidget(covariant Spreadsheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // need to call _init again so the correct frozen positions are set.  But this is an expensive call.
    _init();
  }

  @override
  void dispose() {
    super.dispose();
    _verticalSyncController.dispose();
    _horizontalSyncController.dispose();
    _entranceController.dispose();
    _ghostController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyWidth = totalWidth - frozenColumnWidth + widget.padding.right;
    final bodyHeight = totalHeight - frozenRowHeight + widget.padding.bottom;
    var frozenCorners = ConstrainedBox(constraints: BoxConstraints(maxWidth: frozenColumnWidth, maxHeight: frozenRowHeight), child: Stack(children: _wrapCells(frozenCornerCells, color: widget.frozenRowsColor)));
    var frozenColumns = ConstrainedBox(constraints: BoxConstraints(maxWidth: frozenColumnWidth, maxHeight: bodyHeight), child: Stack(children: _wrapCells(frozenColumnCells)));
    var frozenRows = ConstrainedBox(constraints: BoxConstraints(maxWidth: bodyWidth, maxHeight: frozenRowHeight), child: Stack(children: _wrapCells(frozenRowCells, color: widget.frozenRowsColor)));
    var body = ConstrainedBox(constraints: BoxConstraints(maxWidth: bodyWidth, maxHeight: bodyHeight), child: Stack(children: _wrapCells(bodyCells)));
    const physics = ClampingScrollPhysics();
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            // CORNERS
            frozenCorners,
            // FROZEN ROWS
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
              // FROZEN COLUMNS
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
              // BODY
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
                        child: body,
                      ),
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

  List<Widget> _wrapCells(List<_PositionedCell> cells, {Color color}) {
    return cells.map((cell) {
      return _wrapCell(cell, color: (color == null && widget.striped && widget.stripeColor != null && cell.yIndex % 2 == 0 ? widget.stripeColor : color));
    }).toList();
  }

  Widget _wrapCell(_PositionedCell cell, {Color color}) {
    var _cell = Positioned(
      left: cell.x,
      top: cell.y,
      width: cell.width,
      height: cell.height,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: Border(
            right: widget.border,
            bottom: widget.border,
            top: (widget.outerBorder && cell.alignment.y > 0.0 ? widget.border : BorderSide.none),
            left: (widget.outerBorder && cell.alignment.x > 0.0 ? widget.border : BorderSide.none),
          ),
        ),
        child: Align(
          alignment: cell.alignment,
          child: cell.cell,
        ),
      ),
    );
    return _cell;
  }

  Widget _wrapCellWithAnimation(Widget child) {
    return FadeTransition(
      opacity: _ghostController,
      child: child,
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
        var isCorner = isFrozCol && isFrozRow;
        var isBody = !isFrozCol && !isFrozRow;
        var pos = _PositionedCell(xPos - ((isFrozRow && !isCorner) || isBody ? frozenColumnWidth : 0.0), yPos - ((isFrozCol && !isCorner) || isBody ? frozenRowHeight : 0.0), width, height, align, cell, xIndex: x, yIndex: y);
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
  final int xIndex;
  final int yIndex;
  final double width;
  final double height;
  final Alignment alignment;
  final SpreadsheetCell cell;

  _PositionedCell(this.x, this.y, this.width, this.height, this.alignment, this.cell, {@required this.xIndex, @required this.yIndex});
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
