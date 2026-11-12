class AppModule {
  static const String dashboard = "DASHBOARD";
  static const String leads = "LEADS";
  static const String customers = "CUSTOMERS";
  static const String followUp = "FOLLOW_UP";
  static const String visits = "VISITS";
  static const String proposals = "PROPOSALS";
  static const String packages = "PACKAGES";
  static const String payments = "PAYMENTS";
  static const String workExecution = "WORK_EXECUTION";
  static const String calendar = "CALENDAR";
  static const String myWork = "MY_WORK";
  static const String creativeWork = "CREATIVE_WORK";
  static const String attendance = "ATTENDANCE";
  static const String leave = "LEAVE";
  static const String expenses = "EXPENSES";
  static const String loan = "LOAN";
  static const String remoteWork = "REMOTE_WORK";
  static const String tasks = "TASKS";
  static const String salary = "SALARY";
  static const String notifications = "NOTIFICATIONS";
  static const String reports = "REPORTS";
  static const String profile = "PROFILE";
  static const String settings = "SETTINGS";
  static const String dataCapture = "DATA_CAPTURE";
  static const String commission = "COMMISSION";

  // Customer workspace modules
  static const String customerHome = "CUSTOMER_HOME";
  static const String customerPlans = "CUSTOMER_PLANS";
  static const String customerTrending = "CUSTOMER_TRENDING";
  static const String customerOrders = "CUSTOMER_ORDERS";
  static const String customerInvoices = "CUSTOMER_INVOICES";
  static const String customerProfile = "CUSTOMER_PROFILE";
  static const String customerSsm = "CUSTOMER_SSM";
  static const String customerInfluencers = "CUSTOMER_INFLUENCERS";
  static const String customerInfluencerBookings = "CUSTOMER_INFLUENCER_BOOKINGS";
  static const String customerNotifications = "CUSTOMER_NOTIFICATIONS";
  static const String customerSupport = "CUSTOMER_SUPPORT";
  static const String customerMarketing = "CUSTOMER_MARKETING";

  static const List<String> all = [
    dashboard,
    leads,
    customers,
    dataCapture,
    followUp,
    visits,
    proposals,
    packages,
    payments,
    workExecution,
    calendar,
    myWork,
    creativeWork,
    attendance,
    leave,
    expenses,
    loan,
    remoteWork,
    tasks,
    salary,
    notifications,
    reports,
    profile,
    settings,
    commission,
    customerHome,
    customerPlans,
    customerTrending,
    customerOrders,
    customerInvoices,
    customerProfile,
    customerSsm,
    customerInfluencers,
    customerInfluencerBookings,
    customerNotifications,
    customerSupport,
    customerMarketing,
  ];

  /// Normalize module key to uppercase standard
  static String normalize(String module) {
    var m = module.trim().toUpperCase();
    if (m.startsWith("EMPLOYEE.")) {
      m = m.substring(9);
    }
    switch (m) {
      case "COMMISSION":
      case "COMMISSIONS":
        return commission;
      case "DASHBOARD":
      case "HOME":
        return dashboard;
      case "LEAD":
      case "LEADS":
        return leads;
      case "CUSTOMER":
      case "CUSTOMERS":
      case "CLIENT":
      case "CLIENTS":
        return customers;
      case "DATA_CAPTURE":
      case "DATACAPTURE":
      case "DATA-CAPTURE":
      case "CAPTURE":
        return dataCapture;
      case "FOLLOWUP":
      case "FOLLOW_UP":
      case "FOLLOWUPS":
      case "FOLLOW_UPS":
        return followUp;
      case "VISIT":
      case "VISITS":
        return visits;
      case "PROPOSAL":
      case "PROPOSALS":
      case "QUOTE":
      case "QUOTATION":
      case "QUOTATIONS":
        return proposals;
      case "PACKAGE":
      case "PACKAGES":
      case "PLAN":
      case "PLANS":
        return packages;
      case "PAYMENT":
      case "PAYMENTS":
      case "INVOICE":
      case "INVOICES":
        return payments;
      case "WORK":
      case "WORK_EXECUTION":
      case "WORKEXECUTION":
      case "PROJECT":
      case "PROJECTS":
        return workExecution;
      case "CALENDAR":
      case "CALENDARS":
      case "SCHEDULE":
      case "SCHEDULES":
        return calendar;
      case "MY_WORK":
      case "MYWORK":
        return myWork;
      case "CREATIVE":
      case "CREATIVE_WORK":
      case "CREATIVEWORK":
      case "SSM":
      case "SSM_WORK":
        return creativeWork;
      case "NOTIFICATION":
      case "NOTIFICATIONS":
      case "ALERT":
      case "ALERTS":
        return notifications;
      case "ATTENDANCE":
        return attendance;
      case "LEAVE":
      case "LEAVES":
      case "REQUESTS":
        return leave;
      case "EXPENSE":
      case "EXPENSES":
        return expenses;
      case "REMOTE":
      case "REMOTE_WORK":
      case "REMOTEWORK":
      case "WFH":
        return remoteWork;
      case "TASK":
      case "TASKS":
        return tasks;
      case "SALARY":
      case "SALARY_SLIP":
      case "SALARY_SLIPS":
      case "PAYROLL":
        return salary;
      case "LOAN":
      case "LOANS":
        return loan;
      case "REPORT":
      case "REPORTS":
      case "ANALYTICS":
        return reports;
      case "PROFILE":
      case "USER":
        return profile;
      case "SETTING":
      case "SETTINGS":
        return settings;
      case "CUSTOMER_HOME":
      case "CUSTOMERHOME":
        return customerHome;
      case "CUSTOMER_PLANS":
      case "CUSTOMERPLANS":
        return customerPlans;
      case "CUSTOMER_TRENDING":
      case "CUSTOMERTRENDING":
        return customerTrending;
      case "CUSTOMER_ORDERS":
      case "CUSTOMERORDERS":
        return customerOrders;
      case "CUSTOMER_INVOICES":
      case "CUSTOMERINVOICES":
        return customerInvoices;
      case "CUSTOMER_PROFILE":
      case "CUSTOMERPROFILE":
        return customerProfile;
      case "CUSTOMER_SSM":
      case "CUSTOMERSSM":
        return customerSsm;
      case "CUSTOMER_INFLUENCERS":
      case "CUSTOMERINFLUENCERS":
      case "INFLUENCERS":
      case "INFLUENCER":
        return customerInfluencers;
      case "CUSTOMER_INFLUENCER_BOOKINGS":
      case "CUSTOMERINFLUENCERBOOKINGS":
      case "INFLUENCER_BOOKINGS":
      case "MY_INFLUENCER_BOOKINGS":
        return customerInfluencerBookings;
      case "CUSTOMER_NOTIFICATIONS":
      case "CUSTOMERNOTIFICATIONS":
        return customerNotifications;
      case "CUSTOMER_SUPPORT":
      case "CUSTOMERSUPPORT":
        return customerSupport;
      case "CUSTOMER_MARKETING":
      case "CUSTOMERMARKETING":
        return customerMarketing;
      default:
        return m;
    }
  }
}

class PermissionAction {
  static const String view = "VIEW";
  static const String create = "CREATE";
  static const String edit = "EDIT";
  static const String delete = "DELETE";
  static const String approve = "APPROVE";
  static const String reject = "REJECT";
  static const String export = "EXPORT";
  static const String download = "DOWNLOAD";
  static const String send = "SEND";
  static const String changeStatus = "CHANGE_STATUS";
  static const String changeStage = "CHANGE_STAGE";
  static const String call = "CALL";
  static const String whatsapp = "WHATSAPP";
  static const String email = "EMAIL";
  static const String sendDetails = "SEND_DETAILS";
  static const String scheduleVisit = "SCHEDULE_VISIT";
  static const String followUp = "FOLLOW_UP";
  static const String punchIn = "PUNCH_IN";
  static const String punchOut = "PUNCH_OUT";
  static const String start = "START";
  static const String open = "OPEN";
  static const String upload = "UPLOAD";
  static const String submit = "SUBMIT";
  static const String complete = "COMPLETE";
  static const String publish = "PUBLISH";
  static const String review = "REVIEW";
  static const String reopen = "REOPEN";

  static const List<String> all = [
    view,
    create,
    edit,
    delete,
    approve,
    reject,
    export,
    download,
    send,
    changeStatus,
    changeStage,
    call,
    whatsapp,
    email,
    sendDetails,
    scheduleVisit,
    followUp,
    punchIn,
    punchOut,
    start,
    open,
    upload,
    submit,
    complete,
    publish,
    review,
    reopen,
  ];

  /// Normalize action key to uppercase standard
  static String normalize(String action) {
    final a = action.trim().toUpperCase().replaceAll(".", "_");
    switch (a) {
      case "READ":
      case "VIEW":
      case "SHOW":
      case "GET":
        return view;
      case "ADD":
      case "CREATE":
      case "POST":
      case "NEW":
        return create;
      case "UPDATE":
      case "EDIT":
      case "PUT":
      case "PATCH":
        return edit;
      case "REMOVE":
      case "DELETE":
      case "DEL":
        return delete;
      case "APPROVE":
        return approve;
      case "REJECT":
        return reject;
      case "EXPORT":
        return export;
      case "DOWNLOAD":
        return download;
      case "SEND":
        return send;
      case "CHANGE_STAGE":
      case "STAGE":
      case "CHANGE_STATUS":
      case "STATUS":
        return changeStage;
      case "CALL":
        return call;
      case "WHATSAPP":
        return whatsapp;
      case "EMAIL":
        return email;
      case "SEND_DETAILS":
        return sendDetails;
      case "SCHEDULE_VISIT":
        return scheduleVisit;
      case "FOLLOW_UP":
        return followUp;
      case "PUNCH_IN":
        return punchIn;
      case "PUNCH_OUT":
        return punchOut;
      case "START":
        return start;
      case "OPEN":
        return open;
      case "UPLOAD":
        return upload;
      case "SUBMIT":
        return submit;
      case "COMPLETE":
        return complete;
      case "PUBLISH":
        return publish;
      case "REVIEW":
        return review;
      case "REOPEN":
        return reopen;
      default:
        return a;
    }
  }
}

class UserPermission {
  final String module;
  final String action;

  const UserPermission({required this.module, required this.action});

  factory UserPermission.fromJson(Map<String, dynamic> json) {
    final rawModule = json["module"]?.toString() ?? "";
    final rawAction = json["action"]?.toString() ?? "";
    return UserPermission(
      module: AppModule.normalize(rawModule),
      action: PermissionAction.normalize(rawAction),
    );
  }

  Map<String, dynamic> toJson() => {"module": module, "action": action};

  /// Parse permissions from either a List or a Map (e.g. effectivePermissions, permissionKeys, modules)
  static List<UserPermission> parseAny(dynamic raw) {
    final List<UserPermission> perms = [];
    if (raw == null) return perms;

    if (raw is Iterable) {
      for (final item in raw) {
        if (item is Map) {
          perms.add(UserPermission.fromJson(Map<String, dynamic>.from(item)));
        } else if (item is String) {
          final clean = item.trim();
          if (clean.isEmpty) continue;
          if (clean.contains(":")) {
            final parts = clean.split(":");
            perms.add(
              UserPermission(
                module: AppModule.normalize(parts[0]),
                action: PermissionAction.normalize(parts[1]),
              ),
            );
          } else if (clean.toLowerCase().startsWith("employee.")) {
            // e.g. "employee.leads.change_stage" or "employee.calendar.view" or "employee.calendar"
            final withoutPrefix = clean.substring(9);
            final dotIdx = withoutPrefix.indexOf(".");
            if (dotIdx > 0) {
              final mod = withoutPrefix.substring(0, dotIdx);
              final act = withoutPrefix.substring(dotIdx + 1);
              perms.add(
                UserPermission(
                  module: AppModule.normalize(mod),
                  action: PermissionAction.normalize(act),
                ),
              );
            } else if (withoutPrefix.isNotEmpty) {
              perms.add(
                UserPermission(
                  module: AppModule.normalize(withoutPrefix),
                  action: PermissionAction.view,
                ),
              );
            }
          } else if (clean.contains(".")) {
            // e.g. "calendar.view" or "leads.change_stage"
            final dotIdx = clean.indexOf(".");
            final mod = clean.substring(0, dotIdx);
            final act = clean.substring(dotIdx + 1);
            perms.add(
              UserPermission(
                module: AppModule.normalize(mod),
                action: PermissionAction.normalize(act),
              ),
            );
          } else {
            // Plain module name e.g. "CALENDAR", "LEADS", "MY_WORK", "ATTENDANCE"
            perms.add(
              UserPermission(
                module: AppModule.normalize(clean),
                action: PermissionAction.view,
              ),
            );
          }
        }
      }
    } else if (raw is Map) {
      // Handle Map structure: { "leads": { "view": true, "create": true }, ... } or { "calendar": true }
      raw.forEach((modKey, actVal) {
        final modStr = AppModule.normalize(modKey.toString());
        if (actVal is Map) {
          actVal.forEach((actionKey, isEnabled) {
            if (isEnabled == true) {
              perms.add(
                UserPermission(
                  module: modStr,
                  action: PermissionAction.normalize(actionKey.toString()),
                ),
              );
            }
          });
        } else if (actVal == true) {
          perms.add(
            UserPermission(module: modStr, action: PermissionAction.view),
          );
        }
      });
    }

    // Deduplicate by module + action
    final seen = <String>{};
    final uniquePerms = <UserPermission>[];
    for (final p in perms) {
      final key = '${p.module}:${p.action}';
      if (seen.add(key)) {
        uniquePerms.add(p);
      }
    }

    return uniquePerms;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPermission &&
          runtimeType == other.runtimeType &&
          module == other.module &&
          action == other.action;

  @override
  int get hashCode => module.hashCode ^ action.hashCode;

  @override
  String toString() => "UserPermission($module:$action)";
}

class ModulePermissions {
  final String module;
  final bool canView;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  const ModulePermissions({
    required this.module,
    this.canView = false,
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  bool get hasAny => canView || canCreate || canEdit || canDelete;
}
