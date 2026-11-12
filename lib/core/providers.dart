import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/constants/constants.dart';

class SidebarSelection extends Notifier<SidebarItem> {
  @override
  SidebarItem build() => SidebarItem.dashboard;

  void select(SidebarItem item) => state = item;
}

final sidebarSelectionProvider =
    NotifierProvider<SidebarSelection, SidebarItem>(SidebarSelection.new);
