import 'package:flutter/material.dart';

/// A custom [ScrollPhysics] that only allows user-initiated scrolling/dragging
/// when the content actually exceeds the available viewport size.
class ScrollOnlyWhenNeededPhysics extends ScrollPhysics {
  const ScrollOnlyWhenNeededPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  ScrollOnlyWhenNeededPhysics applyTo(ScrollPhysics? ancestor) {
    return ScrollOnlyWhenNeededPhysics(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // position.maxScrollExtent will be > 0 when the content exceeds the viewport.
    // If the content fits, maxScrollExtent is 0, so dragging will be disabled.
    return position.maxScrollExtent > 0;
  }
}
