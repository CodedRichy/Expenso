import 'package:flutter/material.dart';
import '../models/models.dart';

/// Safe access to route arguments. Use instead of direct cast to avoid crashes
/// when a route is opened without arguments or with the wrong type.
class RouteArgs {
  RouteArgs._();

  static Group? getGroup(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Group ? args : null;
  }

  static Map<String, dynamic>? getMap(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Map<String, dynamic> ? args : null;
  }
}
