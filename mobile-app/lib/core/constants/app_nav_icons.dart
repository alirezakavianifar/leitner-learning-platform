import 'package:flutter/material.dart';

class AppNavIcons {
  static IconData getLeftIcon(String? style) {
    switch (style?.toLowerCase().trim()) {
      case 'arrow':
        return Icons.arrow_back;
      case 'arrow_ios':
        return Icons.arrow_back_ios_new;
      case 'double_chevron':
        return Icons.keyboard_double_arrow_left;
      case 'circle_arrow':
        return Icons.arrow_circle_left;
      case 'triangle':
        return Icons.arrow_left;
      case 'chevron':
      default:
        return Icons.chevron_left;
    }
  }

  static IconData getRightIcon(String? style) {
    switch (style?.toLowerCase().trim()) {
      case 'arrow':
        return Icons.arrow_forward;
      case 'arrow_ios':
        return Icons.arrow_forward_ios;
      case 'double_chevron':
        return Icons.keyboard_double_arrow_right;
      case 'circle_arrow':
        return Icons.arrow_circle_right;
      case 'triangle':
        return Icons.arrow_right;
      case 'chevron':
      default:
        return Icons.chevron_right;
    }
  }
}
