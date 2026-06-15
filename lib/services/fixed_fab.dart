import 'dart:math' as math;
import 'package:flutter/material.dart';

class FixedCenterDockedFabLocation extends StandardFabLocation {
  const FixedCenterDockedFabLocation();

  @override
  double getOffsetX(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) {
    return (scaffoldGeometry.scaffoldSize.width -
            scaffoldGeometry.floatingActionButtonSize.width) /
        2.0 +
        10;
  }

  @override
  double getOffsetY(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) {
    final double contentBottom = scaffoldGeometry.contentBottom;
    final double contentMargin =
        scaffoldGeometry.scaffoldSize.height - contentBottom;
    final double bottomViewPadding = scaffoldGeometry.minViewPadding.bottom;
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;
    final double bottomMinInset = scaffoldGeometry.minInsets.bottom;

    double safeMargin;
    if (contentMargin > bottomMinInset + fabHeight / 2.0) {
      safeMargin = 0.0;
    } else if (bottomMinInset == 0.0) {
      safeMargin = bottomViewPadding;
    } else {
      safeMargin = fabHeight / 2.0 + kFloatingActionButtonMargin;
    }

    final double fabY = contentBottom - fabHeight / 2.0 - safeMargin;

    // Intentionally omit SnackBar and BottomSheet offsets to keep the FAB in its fixed position.

    final double maxFabY =
        scaffoldGeometry.scaffoldSize.height - fabHeight - safeMargin;
    return math.min(maxFabY, fabY);
  }
}
