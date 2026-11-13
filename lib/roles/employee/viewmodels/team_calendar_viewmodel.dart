import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/team_model.dart';
import 'package:quickboom_crm_customer/roles/employee/services/employee_ssm_service.dart';

class TeamCalendarState {
  final bool isLoadingTeams;
  final bool isLoadingCalendar;
  final List<TeamItem> teams;
  final TeamItem? selectedTeam;
  final DateTime currentMonth;
  final DateTime selectedDate;
  final List<CustomerCalendarActivity> allMonthActivities;
  final Map<String, List<CustomerCalendarActivity>> activitiesByDate;
  final String selectedCategory;
  final String? errorMessage;

  const TeamCalendarState({
    this.isLoadingTeams = false,
    this.isLoadingCalendar = false,
    this.teams = const [],
    this.selectedTeam,
    required this.currentMonth,
    required this.selectedDate,
    this.allMonthActivities = const [],
    this.activitiesByDate = const {},
    this.selectedCategory = 'All',
    this.errorMessage,
  });

  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// All activities belonging to the selected date
  List<CustomerCalendarActivity> get selectedDateActivities {
    final key = formatDateKey(selectedDate);
    final list = activitiesByDate[key] ?? [];
    if (selectedCategory == 'All') return list;

    return list.where((a) {
      final label = resolveTaskCategory(a).label;
      return label.toLowerCase() == selectedCategory.toLowerCase() ||
          a.type.toLowerCase() == selectedCategory.toLowerCase() ||
          (a.title != null &&
              a.title!.toLowerCase().contains(selectedCategory.toLowerCase()));
    }).toList();
  }

  /// Distinct activity colors for a given calendar date (up to 3 dots)
  List<Color> getDotsForDate(DateTime date) {
    final key = formatDateKey(date);
    final activities = activitiesByDate[key] ?? [];
    if (activities.isEmpty) return const [];

    final colors = <Color>[];
    for (final act in activities) {
      final c = resolveTaskColor(
        act,
        title: act.title,
        type: act.type,
        status: act.status,
      );
      if (!colors.contains(c)) {
        colors.add(c);
      }
      if (colors.length >= 3) break;
    }
    return colors;
  }

  TeamCalendarState copyWith({
    bool? isLoadingTeams,
    bool? isLoadingCalendar,
    List<TeamItem>? teams,
    TeamItem? selectedTeam,
    DateTime? currentMonth,
    DateTime? selectedDate,
    List<CustomerCalendarActivity>? allMonthActivities,
    Map<String, List<CustomerCalendarActivity>>? activitiesByDate,
    String? selectedCategory,
    String? errorMessage,
    bool clearSelectedTeam = false,
    bool clearError = false,
  }) {
    return TeamCalendarState(
      isLoadingTeams: isLoadingTeams ?? this.isLoadingTeams,
      isLoadingCalendar: isLoadingCalendar ?? this.isLoadingCalendar,
      teams: teams ?? this.teams,
      selectedTeam: clearSelectedTeam
          ? null
          : (selectedTeam ?? this.selectedTeam),
      currentMonth: currentMonth ?? this.currentMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      allMonthActivities: allMonthActivities ?? this.allMonthActivities,
      activitiesByDate: activitiesByDate ?? this.activitiesByDate,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final teamCalendarProvider =
    NotifierProvider<TeamCalendarNotifier, TeamCalendarState>(
      TeamCalendarNotifier.new,
    );

class TeamCalendarNotifier extends Notifier<TeamCalendarState> {
  EmployeeSSMService get _ssmService => ref.read(employeeSSMServiceProvider);

  @override
  TeamCalendarState build() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);

    Future.microtask(() => loadTeams());

    return TeamCalendarState(currentMonth: currentMonth, selectedDate: today);
  }

  /// Initialize and load employee's available teams
  Future<void> loadTeams({int? preferredTeamId, DateTime? initialDate}) async {
    state = state.copyWith(isLoadingTeams: true, clearError: true);

    if (initialDate != null) {
      state = state.copyWith(
        selectedDate: DateTime(
          initialDate.year,
          initialDate.month,
          initialDate.day,
        ),
        currentMonth: DateTime(initialDate.year, initialDate.month, 1),
      );
    }

    try {
      final teams = await _ssmService.fetchEmployeeTeams();
      TeamItem? activeTeam;

      if (preferredTeamId != null) {
        activeTeam = teams.cast<TeamItem?>().firstWhere(
          (t) => t?.id == preferredTeamId,
          orElse: () => null,
        );
      }

      activeTeam ??= teams.isNotEmpty ? teams.first : null;

      state = state.copyWith(
        isLoadingTeams: false,
        teams: teams,
        selectedTeam: activeTeam,
      );

      if (activeTeam != null) {
        await loadMonthCalendar(activeTeam.id, state.currentMonth);
      }
    } catch (e) {
      debugPrint('[TEAM_CALENDAR_NOTIFIER] Error loading teams: $e');
      state = state.copyWith(
        isLoadingTeams: false,
        errorMessage: 'Unable to load teams. Please try again.',
      );
    }
  }

  /// Select a team and load its monthly calendar
  Future<void> selectTeam(TeamItem team) async {
    if (state.selectedTeam?.id == team.id) return;
    state = state.copyWith(selectedTeam: team);
    await loadMonthCalendar(team.id, state.currentMonth);
  }

  /// Select a different month (prev / next)
  Future<void> selectMonth(DateTime newMonth) async {
    final normalizedMonth = DateTime(newMonth.year, newMonth.month, 1);
    final normalizedSelectedDate = DateTime(newMonth.year, newMonth.month, 1);

    state = state.copyWith(
      currentMonth: normalizedMonth,
      selectedDate: normalizedSelectedDate,
    );

    if (state.selectedTeam != null) {
      await loadMonthCalendar(state.selectedTeam!.id, normalizedMonth);
    }
  }

  /// Select a specific calendar date within the active month
  void selectDate(DateTime date) {
    state = state.copyWith(
      selectedDate: DateTime(date.year, date.month, date.day),
    );
  }

  /// Set category filter (e.g. All, Reel Edit, Story Design, Reel Post)
  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  /// Load entire month's activities in one single API request
  Future<void> loadMonthCalendar(int teamId, DateTime month) async {
    state = state.copyWith(isLoadingCalendar: true, clearError: true);

    final startStr =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01';
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final endStr =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-${daysInMonth.toString().padLeft(2, '0')}';

    debugPrint(
      '[TEAM_CALENDAR_NOTIFIER] Fetching month calendar: Team $teamId ($startStr to $endStr)',
    );

    try {
      final activities = await _ssmService.fetchTeamCalendar(
        teamId: teamId,
        startDate: startStr,
        endDate: endStr,
      );

      final grouped = <String, List<CustomerCalendarActivity>>{};
      for (final act in activities) {
        final key = act.scheduledDateStr;
        grouped.putIfAbsent(key, () => []).add(act);
      }

      state = state.copyWith(
        isLoadingCalendar: false,
        allMonthActivities: activities,
        activitiesByDate: grouped,
      );

      debugPrint(
        '[TEAM_CALENDAR_NOTIFIER] Loaded ${activities.length} activities for Team $teamId in $startStr-$endStr',
      );
    } catch (e) {
      debugPrint('[TEAM_CALENDAR_NOTIFIER] Error loading team calendar: $e');
      state = state.copyWith(
        isLoadingCalendar: false,
        errorMessage: 'Unable to load calendar activities.',
      );
    }
  }

  /// Refresh current view
  Future<void> refresh() async {
    if (state.selectedTeam != null) {
      await loadMonthCalendar(state.selectedTeam!.id, state.currentMonth);
    } else {
      await loadTeams();
    }
  }
}
