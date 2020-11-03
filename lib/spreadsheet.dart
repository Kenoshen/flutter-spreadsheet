import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  int _currentIndex = -1;
  int _previousIndex = -1;
  int _initialIndex = -1;
  Axis _reorderAxis = Axis.horizontal;
  bool _scrolling = false;

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
    var frozenCorners = ConstrainedBox(constraints: BoxConstraints(maxWidth: frozenColumnWidth, maxHeight: frozenRowHeight), child: Stack(children: frozenCornerCells.map((w) => w.wrappedInPositioned()).toList()));
    var frozenColumns = ConstrainedBox(constraints: BoxConstraints(maxWidth: frozenColumnWidth, maxHeight: bodyHeight), child: Stack(children: frozenColumnCells.map((w) => w.wrappedInPositioned(child: _wrapInDragTarget(child: w, axis: Axis.vertical, index: w.yIndex))).toList()));
    var frozenRows = ConstrainedBox(constraints: BoxConstraints(maxWidth: bodyWidth, maxHeight: frozenRowHeight), child: Stack(children: frozenRowCells.map((w) => w.wrappedInPositioned(child: _wrapInDragTarget(child: w, axis: Axis.horizontal, index: w.xIndex))).toList()));
    var body = ConstrainedBox(constraints: BoxConstraints(maxWidth: bodyWidth, maxHeight: bodyHeight), child: Stack(children: bodyCells.map((w) => w.wrappedInPositioned()).toList()));
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

  Widget _wrapInDragTarget({@required Widget child, @required Axis axis, @required int index}) {
    // We wrap the drag target in a Builder so that we can scroll to its specific context.
    return Builder(builder: (BuildContext context) {
      Widget dragTarget = DragTarget<int>(
        builder: (BuildContext context, List<int> acceptedCandidates, List<dynamic> rejectedCandidates) {
          // return child;
          return _wrapInDraggable(child: child, axis: axis, index: index);
        },
        onWillAccept: (int indexOfDrag) {
          if (index != _currentIndex) {
            setState(() {
              _previousIndex = _currentIndex;
              _currentIndex = index;
            });
          }
          _scrollTo(context, axis, index);
          return _previousIndex != index;
        },
        onAccept: (int accepted) {},
        onLeave: (Object leaving) {},
      );
      // dragTarget = KeyedSubtree(key: ValueKey(index), child: dragTarget);
      return dragTarget;
    });
  }

  Widget _wrapInDraggable({@required Widget child, @required Axis axis, @required int index}) {
    return LongPressDraggable<int>(
      maxSimultaneousDrags: 1,
      axis: axis,
      data: index,
      ignoringFeedbackSemantics: false,
      feedback: _constructDragFeedback(axis, index),
      child: child,
      childWhenDragging: Opacity(
        opacity: 1,
        child: child,
      ),
      dragAnchor: DragAnchor.child,
      onDragStarted: () {
        setState(() {
          _currentIndex = index;
          _previousIndex = index;
          _initialIndex = index;
          _reorderAxis = axis;
        });
      },
      onDragCompleted: _doReorder,
      onDraggableCanceled: (_, __) {
        _doReorder();
      },
    );
  }

  Widget _constructDragFeedback(Axis axis, int index) {
    final bool isHorizontal = axis == Axis.horizontal;
    double size = isHorizontal ? columnWidths[index] : rowHeights[index];
    double totalLength = isHorizontal ? totalHeight : totalWidth;
    double headerLength = isHorizontal ? frozenRowHeight : frozenColumnWidth;
    List<_PositionedCell> headerCells = (isHorizontal ? frozenRowCells : frozenColumnCells).where((c) => isHorizontal ? c.xIndex == index : c.yIndex == index).toList();
    List<_PositionedCell> contentCells = bodyCells.where((c) => isHorizontal ? c.xIndex == index : c.yIndex == index).toList();
    Widget cellToPositioned(_PositionedCell c) {
      return Positioned(
        child: c,
        top: isHorizontal ? c.y : 0.0,
        left: isHorizontal ? 0.0 : c.x,
        width: c.width,
        height: c.height,
      );
    }

    var headerStack = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isHorizontal ? size : headerLength,
        maxHeight: isHorizontal ? headerLength : size,
      ),
      child: Stack(children: headerCells.map(cellToPositioned).toList()),
    );
    var bodyStack = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isHorizontal ? size : (totalLength - headerLength),
        maxHeight: isHorizontal ? (totalLength - headerLength) : size,
      ),
      child: Stack(children: contentCells.map(cellToPositioned).toList()),
    );
    List<Widget> children = [
      // HEADER
      headerStack,
      // BODY
      Expanded(
        child: bodyStack,
      ),
    ];
    return SizedBox.fromSize(
      size: isHorizontal ? Size(size, totalLength - headerLength) : Size(totalLength - headerLength, size),
      child: Material(
        child: Card(
          child: isHorizontal ? Column(children: children) : Row(children: children),
        ),
        elevation: 6.0,
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  // Scrolls to a target context if that context is not on the screen.
  void _scrollTo(BuildContext context, Axis axis, int index) {
    if (_scrolling) return;
    final RenderObject contextObject = context.findRenderObject();
    final RenderAbstractViewport viewport = RenderAbstractViewport.of(contextObject);
    assert(viewport != null);
    final _scrollController = axis == Axis.horizontal ? _horizontalTitleController : _verticalTitleController;

    final double margin = (axis == Axis.horizontal ? columnWidths[index] : rowHeights[index]) / 2;

    assert(
        _scrollController.hasClients,
        'An attached scroll controller is needed. '
        'You probably forgot to attach one to the parent scroll view that contains this reorderable list.');

    final double scrollOffset = _scrollController.offset;
    final double topOffset = max(
      _scrollController.position.minScrollExtent,
      viewport.getOffsetToReveal(contextObject, 0.0).offset - margin,
    );
    final double bottomOffset = min(
      _scrollController.position.maxScrollExtent,
      viewport.getOffsetToReveal(contextObject, 1.0).offset + margin,
    );
    final bool onScreen = scrollOffset <= topOffset && scrollOffset >= bottomOffset;
    // If the context is off screen, then we request a scroll to make it visible.
    if (!onScreen) {
      _scrolling = true;
      _scrollController.position
          .animateTo(
        scrollOffset < bottomOffset ? bottomOffset : topOffset,
        duration: _animationDuration,
        curve: Curves.easeInOut,
      )
          .then((void value) {
        setState(() {
          _scrolling = false;
        });
      });
    }
  }

  void _doReorder() {
    print("Do reorder: $_reorderAxis $_currentIndex, $_previousIndex, $_initialIndex");
    setState(() {
      _currentIndex = -1;
      _previousIndex = -1;
      _initialIndex = -1;
    });
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
        Color color;
        if (isFrozRow && widget.frozenRowsColor != null)
          color = widget.frozenRowsColor;
        else if (widget.striped && widget.stripeColor != null && y % 2 == 0) color = widget.stripeColor;
        var pos = _PositionedCell(
          xPos - ((isFrozRow && !isCorner) || isBody ? frozenColumnWidth : 0.0),
          yPos - ((isFrozCol && !isCorner) || isBody ? frozenRowHeight : 0.0),
          width,
          height,
          align,
          cell,
          xIndex: x,
          yIndex: y,
          border: widget.border,
          outerBorder: widget.outerBorder,
          color: color,
        );
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

class _PositionedCell extends StatelessWidget {
  final double x;
  final double y;
  final int xIndex;
  final int yIndex;
  final double width;
  final double height;
  final Alignment alignment;
  final Color color;
  final BorderSide border;
  final bool outerBorder;
  final SpreadsheetCell cell;

  _PositionedCell(this.x, this.y, this.width, this.height, this.alignment, this.cell, {@required this.xIndex, @required this.yIndex, this.color, this.border, this.outerBorder});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cell.width,
      height: cell.height,
      decoration: BoxDecoration(
        color: color,
        border: Border(
          right: border,
          bottom: border,
          top: (outerBorder && alignment.y > 0.0 ? border : BorderSide.none),
          left: (outerBorder && alignment.x > 0.0 ? border : BorderSide.none),
        ),
      ),
      child: Align(
        alignment: alignment,
        child: cell,
      ),
    );
  }

  Widget wrappedInPositioned({Widget child}) {
    return Positioned(
      child: child ?? this,
      left: x,
      top: y,
      width: width,
      height: height,
    );
  }
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
