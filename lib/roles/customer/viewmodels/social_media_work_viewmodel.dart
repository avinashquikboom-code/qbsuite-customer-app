import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/roles/customer/models/social_media_work_model.dart';
import 'package:quickboom_crm_customer/roles/customer/services/social_media_work_service.dart';

class SocialMediaWorkState {
  final bool isLoading;
  final bool isSaving;
  final List<CustomerSocialMediaHandler> handlers;
  final String selectedPlatform;
  final String accountName;
  final String accountUrl;
  final String password;
  final String handlerName;
  final String selectedWorkType;
  final DateTime? startDate;
  final int durationDays;
  final String notes;
  final Map<String, String> errors;
  final bool isSubmitted;
  final String? errorMessage;

  const SocialMediaWorkState({
    this.isLoading = false,
    this.isSaving = false,
    this.handlers = const [],
    this.selectedPlatform = 'INSTAGRAM',
    this.accountName = '',
    this.accountUrl = '',
    this.password = '',
    this.handlerName = '',
    this.selectedWorkType = 'Content Posting',
    this.startDate,
    this.durationDays = 30,
    this.notes = '',
    this.errors = const {},
    this.isSubmitted = false,
    this.errorMessage,
  });

  /// Compatibility alias for scheduled works list
  List<CustomerSocialMediaHandler> get scheduledWorks => handlers;

  // Calculated End Date
  DateTime? get endDate {
    if (startDate == null) return null;
    return startDate!.add(Duration(days: durationDays));
  }

  SocialMediaWorkState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<CustomerSocialMediaHandler>? handlers,
    String? selectedPlatform,
    String? accountName,
    String? accountUrl,
    String? password,
    String? handlerName,
    String? selectedWorkType,
    DateTime? Function()? startDate,
    int? durationDays,
    String? notes,
    Map<String, String>? errors,
    bool? isSubmitted,
    String? Function()? errorMessage,
  }) {
    return SocialMediaWorkState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      handlers: handlers ?? this.handlers,
      selectedPlatform: selectedPlatform ?? this.selectedPlatform,
      accountName: accountName ?? this.accountName,
      accountUrl: accountUrl ?? this.accountUrl,
      password: password ?? this.password,
      handlerName: handlerName ?? this.handlerName,
      selectedWorkType: selectedWorkType ?? this.selectedWorkType,
      startDate: startDate != null ? startDate() : this.startDate,
      durationDays: durationDays ?? this.durationDays,
      notes: notes ?? this.notes,
      errors: errors ?? this.errors,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class SocialMediaWorkNotifier extends Notifier<SocialMediaWorkState> {
  @override
  SocialMediaWorkState build() {
    // Initial fetch on build
    Future.microtask(() => loadHandlers());

    return SocialMediaWorkState(
      isLoading: true,
      startDate: DateTime.now(),
      durationDays: 30,
    );
  }

  Future<void> loadHandlers() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final service = ref.read(socialMediaWorkServiceProvider);
      final items = await service.getSocialMediaHandlers();
      state = state.copyWith(isLoading: false, handlers: items);
    } catch (e) {
      debugPrint('[SOCIAL_MEDIA_NOTIFIER_ERROR] $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: () =>
            'Failed to load social media handlers. Please retry.',
      );
    }
  }

  void selectPlatform(String platform) {
    state = state.copyWith(
      selectedPlatform: platform,
      errors: Map.from(state.errors)..remove('platform'),
    );
  }

  void setAccountName(String value) {
    state = state.copyWith(
      accountName: value,
      errors: Map.from(state.errors)..remove('accountName'),
    );
  }

  void setAccountUrl(String value) {
    state = state.copyWith(accountUrl: value);
  }

  void setPassword(String value) {
    state = state.copyWith(
      password: value,
      errors: Map.from(state.errors)..remove('password'),
    );
  }

  void setHandlerName(String value) {
    state = state.copyWith(handlerName: value);
  }

  void selectWorkType(String workType) {
    state = state.copyWith(
      selectedWorkType: workType,
      errors: Map.from(state.errors)..remove('workType'),
    );
  }

  void setStartDate(DateTime date) {
    state = state.copyWith(
      startDate: () => date,
      errors: Map.from(state.errors)..remove('startDate'),
    );
  }

  void setDurationDays(int days) {
    state = state.copyWith(durationDays: days);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  bool validate() {
    final newErrors = <String, String>{};

    if (state.selectedPlatform.isEmpty) {
      newErrors['platform'] = 'Please select a platform.';
    }
    if (state.accountName.trim().isEmpty) {
      newErrors['accountName'] = 'Please enter your account handle or name.';
    }
    if (state.password.trim().isEmpty) {
      newErrors['password'] = 'Please enter account password.';
    }
    if (state.selectedWorkType.isEmpty) {
      newErrors['workType'] = 'Please select a work type.';
    }
    if (state.startDate == null) {
      newErrors['startDate'] = 'Please select a start date.';
    }

    state = state.copyWith(errors: newErrors);
    return newErrors.isEmpty;
  }

  Future<bool> submit() async {
    if (!validate()) return false;

    state = state.copyWith(isSaving: true, errorMessage: () => null);

    try {
      final service = ref.read(socialMediaWorkServiceProvider);
      final created = await service.createHandler(
        platform: state.selectedPlatform,
        accountName: state.accountName.trim(),
        accountUrl: state.accountUrl.trim().isNotEmpty
            ? state.accountUrl.trim()
            : null,
        password: state.password.trim().isNotEmpty
            ? state.password.trim()
            : null,
        handlerName: state.handlerName.trim().isNotEmpty
            ? state.handlerName.trim()
            : null,
        workType: state.selectedWorkType,
        startDate: state.startDate,
        endDate: state.endDate,
        durationDays: state.durationDays,
        notes: state.notes.trim().isNotEmpty ? state.notes.trim() : null,
      );

      if (created != null) {
        final updatedList = [created, ...state.handlers];
        state = state.copyWith(
          isSaving: false,
          isSubmitted: true,
          handlers: updatedList,
          accountName: '',
          accountUrl: '',
          password: '',
          handlerName: '',
          notes: '',
        );
        return true;
      } else {
        state = state.copyWith(
          isSaving: false,
          errorMessage: () => 'Failed to create handler. Please check details.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[SOCIAL_MEDIA_SUBMIT_ERROR]');
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => 'Failed to save account. Please check details.',
      );
      return false;
    }
  }

  Future<bool> updateHandler({
    required int id,
    required String platform,
    required String accountName,
    String? accountUrl,
    String? password,
    String? handlerName,
    String? workType,
    String? notes,
  }) async {
    state = state.copyWith(isSaving: true, errorMessage: () => null);

    try {
      final service = ref.read(socialMediaWorkServiceProvider);
      final updated = await service.updateHandler(
        id: id,
        platform: platform,
        accountName: accountName,
        accountUrl: accountUrl,
        password: password,
        handlerName: handlerName,
        workType: workType,
        notes: notes,
      );

      if (updated != null) {
        final updatedList = state.handlers
            .map((h) => h.id == id ? updated : h)
            .toList();
        state = state.copyWith(
          isSaving: false,
          handlers: updatedList,
          accountName: '',
          accountUrl: '',
          password: '',
          handlerName: '',
          notes: '',
        );
        return true;
      } else {
        state = state.copyWith(
          isSaving: false,
          errorMessage: () => 'Failed to update handler. Please check details.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[SOCIAL_MEDIA_UPDATE_ERROR]');
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => 'Failed to update handler. Please check details.',
      );
      return false;
    }
  }

  Future<void> deleteHandler(int id) async {
    final service = ref.read(socialMediaWorkServiceProvider);
    final success = await service.deleteHandler(id);
    if (success) {
      final updated = state.handlers.where((h) => h.id != id).toList();
      state = state.copyWith(handlers: updated);
    }
  }

  void resetForm() {
    state = state.copyWith(
      selectedPlatform: 'INSTAGRAM',
      accountName: '',
      accountUrl: '',
      password: '',
      handlerName: '',
      selectedWorkType: 'Content Posting',
      startDate: () => DateTime.now(),
      durationDays: 30,
      notes: '',
      errors: {},
      isSubmitted: false,
      errorMessage: () => null,
    );
  }
}

final socialMediaWorkProvider =
    NotifierProvider<SocialMediaWorkNotifier, SocialMediaWorkState>(
      SocialMediaWorkNotifier.new,
    );
