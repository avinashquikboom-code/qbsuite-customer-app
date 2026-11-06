import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardQuery extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

