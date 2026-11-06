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
  static const accessTimeRounded = Remix.time_line;
  static const accountBalanceRounded = Remix.bank_line;
  static const add = Remix.add_line;
  static const arrowBack = Remix.arrow_left_line;
  static const arrowForwardIosRounded = Remix.arrow_right_s_line;
  static const arrowForwardRounded = Remix.arrow_right_line;
  static const autoAwesome = Remix.sparkling_line;
  static const boltRounded = Remix.flashlight_line;
  static const brokenImage = Remix.image_line;
  static const brokenImageOutlined = Remix.image_line;
  static const business = Remix.building_line;
  static const businessCenterRounded = Remix.briefcase_line;
  static const businessOutlined = Remix.building_line;
  static const businessRounded = Remix.building_line;
  static const calendarMonth = Remix.calendar_2_line;
  static const calendarTodayOutlined = Remix.calendar_line;
  static const callOutlined = Remix.phone_line;
  static const callRounded = Remix.phone_line;
  static const check = Remix.check_line;
  static const checkBox = Remix.checkbox_fill;
  static const checkBoxOutlineBlankRounded = Remix.checkbox_blank_line;
  static const checkBoxRounded = Remix.checkbox_fill;
  static const checkCircle = Remix.checkbox_circle_fill;
  static const checkCircleOutline = Remix.checkbox_circle_line;
  static const checkCircleRounded = Remix.checkbox_circle_fill;
  static const chevronRight = Remix.arrow_right_s_line;
  static const chevronRightRounded = Remix.arrow_right_s_line;
  static const clearAllRounded = Remix.filter_off_line;
  static const close = Remix.close_line;
  static const closeRounded = Remix.close_line;
  static const contentCutRounded = Remix.scissors_line;
  static const copyOutlined = Remix.file_copy_line;
  static const copyRounded = Remix.file_copy_line;
  static const dateRange = Remix.calendar_2_line;
  static const deleteOutline = Remix.delete_bin_line;
  static const directionsCarRounded = Remix.car_line;
  static const editNoteRounded = Remix.edit_2_line;
  static const editOutlined = Remix.edit_line;
  static const errorOutline = Remix.error_warning_line;
  static const errorOutlineRounded = Remix.error_warning_line;
  static const favorite = Remix.heart_fill;
  static const favoriteBorder = Remix.heart_line;
  static const fileDownloadOutlined = Remix.download_line;
  static const fingerprintRounded = Remix.fingerprint_line;
  static const fitnessCenterRounded = Remix.boxing_line;
  static const flightTakeoffRounded = Remix.flight_takeoff_line;
  static const groupsRounded = Remix.group_line;
  static const historyEduRounded = Remix.quill_pen_line;
  static const historyRounded = Remix.history_line;
  static const historyToggleOffRounded = Remix.time_line;
  static const homeWorkRounded = Remix.building_4_line;
  static const hotelRounded = Remix.hotel_line;
  static const hourglassTopRounded = Remix.hourglass_line;
  static const infoOutline = Remix.information_line;
  static const infoOutlineRounded = Remix.information_line;
  static const inventory2Outlined = Remix.archive_line;
  static const language = Remix.global_line;
  static const languageOutlined = Remix.global_line;
  static const languageRounded = Remix.global_line;
  static const listAlt = Remix.list_check;
  static const localHospitalRounded = Remix.hospital_line;
  static const locationOnOutlined = Remix.map_pin_line;
  static const locationOnRounded = Remix.map_pin_line;
  static const lockOutline = Remix.lock_line;
  static const loginRounded = Remix.login_box_line;
  static const logout = Remix.logout_box_r_line;
  static const logoutRounded = Remix.logout_box_r_line;
  static const mailOutline = Remix.mail_line;
  static const mailOutlined = Remix.mail_line;
  static const mapOutlined = Remix.map_line;
  static const mapRounded = Remix.map_line;
  static const medicalServicesRounded = Remix.first_aid_kit_line;
  static const myLocationRounded = Remix.focus_3_line;
  static const openInBrowserRounded = Remix.window_line;
  static const openInNew = Remix.external_link_line;
  static const pauseRounded = Remix.pause_line;
  static const personAddAlt1 = Remix.user_add_line;
  static const personAddAlt1Rounded = Remix.user_add_line;
  static const phoneOutlined = Remix.phone_line;
  static const pieChartRounded = Remix.pie_chart_line;
  static const playArrowRounded = Remix.play_line;
  static const radioButtonUnchecked = Remix.checkbox_blank_circle_line;
  static const refresh = Remix.refresh_line;
  static const refreshRounded = Remix.refresh_line;
  static const restaurantRounded = Remix.restaurant_line;
  static const reviewsOutlined = Remix.chat_quote_line;
  static const schoolRounded = Remix.graduation_cap_line;
  static const search = Remix.search_line;
  static const searchRounded = Remix.search_line;
  static const securityRounded = Remix.shield_check_line;
  static const shareOutlined = Remix.share_line;
  static const starOutlineRounded = Remix.star_line;
  static const starRounded = Remix.star_fill;
  static const storefrontOutlined = Remix.store_2_line;
  static const storefrontRounded = Remix.store_2_line;
  static const travelExploreOutlined = Remix.earth_line;
  static const travelExploreRounded = Remix.earth_line;
  static const trendingUpRounded = Remix.line_chart_line;
  static const tuneRounded = Remix.equalizer_line;
  static const verified = Remix.verified_badge_line;
  static const videocamOffRounded = Remix.vidicon_line;
  static const visibilityOffOutlined = Remix.eye_off_line;
  static const visibilityOutlined = Remix.eye_line;
  static const volumeOffRounded = Remix.volume_mute_line;
  static const volumeUpRounded = Remix.volume_up_line;
  static const warningAmberRounded = Remix.alert_line;
}
