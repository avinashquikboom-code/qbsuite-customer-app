import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

enum AppIcon {
  home,
  profile,
  notifications,
  search,
  back,
  next,
  down,
  menu,
  logout,
  lock,
  empty,
  grid,
  close,
}

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
  const RemixIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });
  final AppIcon icon;
  final double size;
  final Color? color;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Icon(
    RemixIcons.mapping[icon],
    size: size,
    color: color,
    semanticLabel: semanticLabel,
  );
}

/// Compatibility glyphs for legacy views; all resolve to Remix Icons.
abstract final class LegacyRemixIcons {
  static const access_time_rounded = Remix.time_line;
  static const account_balance_rounded = Remix.bank_line;
  static const add = Remix.add_line;
  static const arrow_back = Remix.arrow_left_line;
  static const arrow_forward_ios_rounded = Remix.arrow_right_s_line;
  static const arrow_forward_rounded = Remix.arrow_right_line;
  static const auto_awesome = Remix.sparkling_line;
  static const bolt_rounded = Remix.flashlight_line;
  static const broken_image = Remix.image_line;
  static const broken_image_outlined = Remix.image_line;
  static const business = Remix.building_line;
  static const business_center_rounded = Remix.briefcase_line;
  static const business_outlined = Remix.building_line;
  static const business_rounded = Remix.building_line;
  static const calendar_month = Remix.calendar_2_line;
  static const calendar_today_outlined = Remix.calendar_line;
  static const call_outlined = Remix.phone_line;
  static const call_rounded = Remix.phone_line;
  static const check = Remix.check_line;
  static const check_box = Remix.checkbox_fill;
  static const check_box_outline_blank_rounded = Remix.checkbox_blank_line;
  static const check_box_rounded = Remix.checkbox_fill;
  static const check_circle = Remix.checkbox_circle_fill;
  static const check_circle_outline = Remix.checkbox_circle_line;
  static const check_circle_rounded = Remix.checkbox_circle_fill;
  static const chevron_right = Remix.arrow_right_s_line;
  static const chevron_right_rounded = Remix.arrow_right_s_line;
  static const clear_all_rounded = Remix.filter_off_line;
  static const close = Remix.close_line;
  static const close_rounded = Remix.close_line;
  static const content_cut_rounded = Remix.scissors_line;
  static const copy_outlined = Remix.file_copy_line;
  static const copy_rounded = Remix.file_copy_line;
  static const date_range = Remix.calendar_2_line;
  static const delete_outline = Remix.delete_bin_line;
  static const directions_car_rounded = Remix.car_line;
  static const edit_note_rounded = Remix.edit_2_line;
  static const edit_outlined = Remix.edit_line;
  static const error_outline = Remix.error_warning_line;
  static const error_outline_rounded = Remix.error_warning_line;
  static const favorite = Remix.heart_fill;
  static const favorite_border = Remix.heart_line;
  static const file_download_outlined = Remix.download_line;
  static const fingerprint_rounded = Remix.fingerprint_line;
  static const fitness_center_rounded = Remix.boxing_line;
  static const flight_takeoff_rounded = Remix.flight_takeoff_line;
  static const groups_rounded = Remix.group_line;
  static const history_edu_rounded = Remix.quill_pen_line;
  static const history_rounded = Remix.history_line;
  static const history_toggle_off_rounded = Remix.time_line;
  static const home_work_rounded = Remix.building_4_line;
  static const hotel_rounded = Remix.hotel_line;
  static const hourglass_top_rounded = Remix.hourglass_line;
  static const info_outline = Remix.information_line;
  static const info_outline_rounded = Remix.information_line;
  static const inventory_2_outlined = Remix.archive_line;
  static const language = Remix.global_line;
  static const language_outlined = Remix.global_line;
  static const language_rounded = Remix.global_line;
  static const list_alt = Remix.list_check;
  static const local_hospital_rounded = Remix.hospital_line;
  static const location_on_outlined = Remix.map_pin_line;
  static const location_on_rounded = Remix.map_pin_line;
  static const lock_outline = Remix.lock_line;
  static const login_rounded = Remix.login_box_line;
  static const logout = Remix.logout_box_r_line;
  static const logout_rounded = Remix.logout_box_r_line;
  static const mail_outline = Remix.mail_line;
  static const mail_outlined = Remix.mail_line;
  static const map_outlined = Remix.map_line;
  static const map_rounded = Remix.map_line;
  static const medical_services_rounded = Remix.first_aid_kit_line;
  static const my_location_rounded = Remix.focus_3_line;
  static const open_in_browser_rounded = Remix.window_line;
  static const open_in_new = Remix.external_link_line;
  static const pause_rounded = Remix.pause_line;
  static const person_add_alt_1 = Remix.user_add_line;
  static const person_add_alt_1_rounded = Remix.user_add_line;
  static const phone_outlined = Remix.phone_line;
  static const pie_chart_rounded = Remix.pie_chart_line;
  static const play_arrow_rounded = Remix.play_line;
  static const radio_button_unchecked = Remix.checkbox_blank_circle_line;
  static const refresh = Remix.refresh_line;
  static const refresh_rounded = Remix.refresh_line;
  static const restaurant_rounded = Remix.restaurant_line;
  static const reviews_outlined = Remix.chat_quote_line;
  static const school_rounded = Remix.graduation_cap_line;
  static const search = Remix.search_line;
  static const search_rounded = Remix.search_line;
  static const security_rounded = Remix.shield_check_line;
  static const share_outlined = Remix.share_line;
  static const star_outline_rounded = Remix.star_line;
  static const star_rounded = Remix.star_fill;
  static const storefront_outlined = Remix.store_2_line;
  static const storefront_rounded = Remix.store_2_line;
  static const travel_explore_outlined = Remix.earth_line;
  static const travel_explore_rounded = Remix.earth_line;
  static const trending_up_rounded = Remix.line_chart_line;
  static const tune_rounded = Remix.equalizer_line;
  static const verified = Remix.verified_badge_line;
  static const videocam_off_rounded = Remix.vidicon_line;
  static const visibility_off_outlined = Remix.eye_off_line;
  static const visibility_outlined = Remix.eye_line;
  static const volume_off_rounded = Remix.volume_mute_line;
  static const volume_up_rounded = Remix.volume_up_line;
  static const warning_amber_rounded = Remix.alert_line;
}
