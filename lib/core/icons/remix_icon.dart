import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

enum AppIcon { home, profile, notifications, search, back, next, down, menu, logout, lock, empty, grid, close }

abstract final class RemixIcons {
  static const mapping = <AppIcon, IconData>{
    AppIcon.home: Remix.home_4_line,
    AppIcon.profile: Remix.user_line,
    AppIcon.notifications: Remix.notification_3_line,
    AppIcon.search: Remix.search_line,
    AppIcon.back: Remix.arrow_left_line,
    AppIcon.next: Remix.arrow_right_s_line,
    AppIcon.down: Remix.arrow_down_s_line,
    AppIcon.menu: Remix.menu_line,
    AppIcon.logout: Remix.logout_box_r_line,
    AppIcon.lock: Remix.lock_line,
    AppIcon.empty: Remix.inbox_line,
    AppIcon.grid: Remix.dashboard_line,
    AppIcon.close: Remix.close_line,
  };
}

class RemixIcon extends StatelessWidget {
  const RemixIcon(this.icon, {super.key, this.size = 24, this.color, this.semanticLabel});
  final AppIcon icon;
  final double size;
  final Color? color;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Icon(RemixIcons.mapping[icon], size: size, color: color, semanticLabel: semanticLabel);
}
