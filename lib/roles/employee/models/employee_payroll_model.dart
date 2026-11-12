class SalarySlipItem {
  final String id;
  final String month;
  final int? year;
  final String date;
  final double basicSalary;
  final double hra;
  final double allowances;
  final double specialAllowance;
  final double commission;
  final double overtime;
  final double bonus;
  final double reimbursement;
  final double grossSalary;
  final double pf;
  final double esi;
  final double professionalTax;
  final double tds;
  final double otherDeductions;
  final double loanDeduction;
  final double unpaidLeaveDeduction;
  final double deductions;
  final double netSalary;
  final double calendarDays;
  final double workingDays;
  final double presentDays;
  final double absentDays;
  final double halfDays;
  final double paidLeaveDays;
  final double unpaidLeaveDays;
  final double weeklyOffDays;
  final double holidayDays;
  final double extraWorkingDays;
  final List<String> extraWorkingDates;
  final double payableDays;
  final double extraWorkingPay;
  final double monthlySalary;
  final double attendanceSalary;
  final String compensationMode;
  final double monthlyTarget;
  final double achievedAmount;
  final double eligibleSalary;
  final double registeredSalary;
  final double belowTargetSalary;
  final double remainingAmount;
  final double achievementPercent;
  final String targetStatus;
  final String overtimeHours;
  final double lateMarks;
  final double lateDeduction;
  final double otActualHours;
  final double otPayableHours;
  final double otPayout;
  final Map<String, dynamic>? attendanceSummary;
  final Map<String, dynamic>? salaryBreakdown;
  final String? status;
  final String? downloadUrl;
  final String? slipNumber;
  final String? paymentMode;
  final String? paymentReference;
  final Map<String, dynamic>? bankDetails;
  final Map<String, dynamic>? employeeDetails;

  SalarySlipItem({
    required this.id,
    required this.month,
    this.year,
    required this.date,
    required this.basicSalary,
    this.hra = 0.0,
    required this.allowances,
    this.specialAllowance = 0.0,
    required this.deductions,
    required this.commission,
    this.overtime = 0.0,
    this.bonus = 0.0,
    this.reimbursement = 0.0,
    this.grossSalary = 0.0,
    this.pf = 0.0,
    this.esi = 0.0,
    this.professionalTax = 0.0,
    this.tds = 0.0,
    this.otherDeductions = 0.0,
    this.loanDeduction = 0.0,
    this.unpaidLeaveDeduction = 0.0,
    required this.netSalary,
    this.calendarDays = 0.0,
    this.workingDays = 0.0,
    this.presentDays = 0.0,
    this.absentDays = 0.0,
    this.halfDays = 0.0,
    this.paidLeaveDays = 0.0,
    this.unpaidLeaveDays = 0.0,
    this.weeklyOffDays = 0.0,
    this.holidayDays = 0.0,
    this.extraWorkingDays = 0.0,
    this.extraWorkingDates = const [],
    this.payableDays = 0.0,
    this.extraWorkingPay = 0.0,
    this.monthlySalary = 0.0,
    this.attendanceSalary = 0.0,
    this.compensationMode = 'FIXED',
    this.monthlyTarget = 0.0,
    this.achievedAmount = 0.0,
    this.eligibleSalary = 0.0,
    this.registeredSalary = 0.0,
    this.belowTargetSalary = 0.0,
    this.remainingAmount = 0.0,
    this.achievementPercent = 0.0,
    this.targetStatus = '',
    this.overtimeHours = '0h 0m',
    this.lateMarks = 0,
    this.lateDeduction = 0,
    this.otActualHours = 0,
    this.otPayableHours = 0,
    this.otPayout = 0,
    this.attendanceSummary,
    this.salaryBreakdown,
    required this.status,
    this.downloadUrl,
    this.slipNumber,
    this.paymentMode,
    this.paymentReference,
    this.bankDetails,
    this.employeeDetails,
  });

  factory SalarySlipItem.fromJson(Map<String, dynamic> json) {
    final pi = (json['payrollItem'] is Map)
        ? Map<String, dynamic>.from(json['payrollItem'])
        : <String, dynamic>{};

    final net = (json['netSalary'] ?? pi['netSalary'] ?? 0).toDouble();
    final gross = (json['grossSalary'] ?? pi['grossSalary'] ?? net).toDouble();
    final deduct = (json['totalDeductions'] ?? json['deductions'] ?? pi['totalDeductions'] ?? 0)
        .toDouble();
    final basic = (pi['basicSalary'] ?? json['basicSalary'] ?? 0).toDouble();
    final hraVal = (pi['hra'] ?? json['hra'] ?? 0).toDouble();
    final allow = (pi['allowances'] ?? json['allowances'] ?? 0).toDouble();
    final special = (pi['specialAllowance'] ?? json['specialAllowance'] ?? 0).toDouble();
    final comm = (pi['commission'] ?? json['commission'] ?? 0).toDouble();
    final ovt = (pi['overtime'] ?? json['overtime'] ?? 0).toDouble();
    final bon = (pi['bonus'] ?? json['bonus'] ?? 0).toDouble();
    final reimb = (pi['reimbursement'] ?? json['reimbursement'] ?? 0)
        .toDouble();
    final pfVal = (pi['pf'] ?? json['pf'] ?? 0).toDouble();
    final esiVal = (pi['esi'] ?? json['esi'] ?? 0).toDouble();
    final ptVal = (pi['professionalTax'] ?? json['professionalTax'] ?? 0).toDouble();
    final tdsVal = (pi['tds'] ?? json['tds'] ?? 0).toDouble();
    final otherDed = (pi['otherDeductions'] ?? json['otherDeductions'] ?? 0).toDouble();
    final loanDed = (pi['loanDeduction'] ?? json['loanDeduction'] ?? 0)
        .toDouble();
    final unpaidLeaveDed =
        (pi['unpaidLeaveDeduction'] ?? json['unpaidLeaveDeduction'] ?? 0)
            .toDouble();

    final emp = (json['employee'] is Map)
        ? Map<String, dynamic>.from(json['employee'])
        : null;
    final bDetails = (json['bankDetails'] is Map)
        ? Map<String, dynamic>.from(json['bankDetails'])
        : (emp != null && emp['bankDetails'] is Map)
            ? Map<String, dynamic>.from(emp['bankDetails'])
            : null;
    final slipNum = json['slipNumber']?.toString();
    final pMode = json['paymentMode']?.toString() ??
        json['paymentMethod']?.toString() ??
        pi['paymentMode']?.toString();
    final pRef = json['paymentReference']?.toString() ??
        json['transactionId']?.toString() ??
        slipNum;

    final attSummary = (json['attendanceSummary'] is Map)
        ? Map<String, dynamic>.from(json['attendanceSummary'])
        : (pi['calculationSnapshot'] is Map &&
                pi['calculationSnapshot']['attendanceSummary'] is Map)
            ? Map<String, dynamic>.from(
                pi['calculationSnapshot']['attendanceSummary'])
            : <String, dynamic>{};

    final sBreakdown = (json['salaryBreakdown'] is Map)
        ? Map<String, dynamic>.from(json['salaryBreakdown'])
        : null;

    final extraPay = (json['extraWorkingPay'] ??
            pi['extraWorkingPay'] ??
            sBreakdown?['extraWorkingPay'] ??
            0)
        .toDouble();
    final mSalary = (json['monthlySalary'] ??
            pi['monthlySalary'] ??
            sBreakdown?['monthlySalary'] ??
            (basic + hraVal + allow + special))
        .toDouble();
    final attSal = (json['attendanceSalary'] ??
            pi['attendanceSalary'] ??
            sBreakdown?['attendanceSalary'] ??
            gross)
        .toDouble();

    final numCalendarDays = (attSummary['calendarDays'] ??
            json['calendarDays'] ??
            pi['calendarDays'] ??
            0)
        .toDouble();
    final numExtraWorkingDays = (attSummary['extraWorkingDays'] ??
            json['extraWorkingDays'] ??
            pi['extraWorkingDays'] ??
            0)
        .toDouble();
    final listExtraWorkingDates = (attSummary['extraWorkingDates'] is List)
        ? List<String>.from((attSummary['extraWorkingDates'] as List).map((e) => e.toString()))
        : (json['extraWorkingDates'] is List)
            ? List<String>.from((json['extraWorkingDates'] as List).map((e) => e.toString()))
            : (pi['extraWorkingDates'] is List)
                ? List<String>.from((pi['extraWorkingDates'] as List).map((e) => e.toString()))
                : <String>[];
    final numPayableDays = (attSummary['payableDays'] ??
            json['payableDays'] ??
            pi['payableDays'] ??
            0)
        .toDouble();

    final numWorkingDays = (attSummary['workingDays'] ??
            json['workingDays'] ??
            pi['workingDays'] ??
            0)
        .toDouble();
    final numPresentDays = (attSummary['presentDays'] ??
            json['presentDays'] ??
            pi['presentDays'] ??
            0)
        .toDouble();
    final numAbsentDays = (attSummary['absentDays'] ??
            json['absentDays'] ??
            pi['absentDays'] ??
            0)
        .toDouble();
    final numHalfDays = (attSummary['halfDays'] ??
            json['halfDays'] ??
            pi['halfDays'] ??
            0)
        .toDouble();
    final numPaidLeaveDays = (attSummary['paidLeaveDays'] ??
            json['paidLeaveDays'] ??
            pi['paidLeaveDays'] ??
            0)
        .toDouble();
    final numUnpaidLeaveDays = (attSummary['unpaidLeaveDays'] ??
            json['unpaidLeaveDays'] ??
            pi['unpaidLeaveDays'] ??
            0)
        .toDouble();
    final numWeeklyOffDays = (attSummary['weeklyOffDays'] ??
            json['weeklyOffDays'] ??
            pi['weeklyOffDays'] ??
            0)
        .toDouble();
    final numHolidayDays = (attSummary['holidayDays'] ??
            json['holidayDays'] ??
            pi['holidayDays'] ??
            0)
        .toDouble();
    final strOvertimeHours = attSummary['overtimeLabel']?.toString() ??
        json['overtimeHours']?.toString() ??
        '0h 0m';

    return SalarySlipItem(
      id: (json['id'] ?? '').toString(),
      month:
          (json['payPeriod'] ??
                  json['monthName'] ??
                  json['month'] ??
                  'Current Month')
              .toString(),
      year: json['year'] as int?,
      date: (json['generatedAt'] ?? json['date'] ?? json['createdAt'] ?? '')
          .toString(),
      basicSalary: basic,
      hra: hraVal,
      allowances: allow,
      specialAllowance: special,
      deductions: deduct,
      commission: comm,
      overtime: ovt,
      bonus: bon,
      reimbursement: reimb,
      grossSalary: gross,
      pf: pfVal,
      esi: esiVal,
      professionalTax: ptVal,
      tds: tdsVal,
      otherDeductions: otherDed,
      loanDeduction: loanDed,
      unpaidLeaveDeduction: unpaidLeaveDed,
      netSalary: net,
      calendarDays: numCalendarDays,
      workingDays: numWorkingDays,
      presentDays: numPresentDays,
      absentDays: numAbsentDays,
      halfDays: numHalfDays,
      paidLeaveDays: numPaidLeaveDays,
      unpaidLeaveDays: numUnpaidLeaveDays,
      weeklyOffDays: numWeeklyOffDays,
      holidayDays: numHolidayDays,
      extraWorkingDays: numExtraWorkingDays,
      extraWorkingDates: listExtraWorkingDates,
      payableDays: numPayableDays,
      extraWorkingPay: extraPay,
      monthlySalary: mSalary,
      attendanceSalary: attSal,
      compensationMode: (json['compensationMode'] ?? pi['compensationMode'] ?? 'FIXED').toString(),
      monthlyTarget: (json['monthlyTarget'] ?? pi['monthlyTarget'] ?? 0).toDouble(),
      achievedAmount: (json['achievedAmount'] ?? pi['achievedAmount'] ?? 0).toDouble(),
      eligibleSalary: (json['eligibleSalary'] ?? pi['eligibleSalary'] ?? 0).toDouble(),
      registeredSalary: (json['registeredSalary'] ?? pi['registeredSalary'] ?? 0).toDouble(),
      belowTargetSalary: (json['belowTargetSalary'] ?? pi['belowTargetSalary'] ?? 0).toDouble(),
      remainingAmount: (json['remainingAmount'] ?? pi['remainingAmount'] ?? 0).toDouble(),
      achievementPercent: (json['achievementPercent'] ?? pi['achievementPercent'] ?? 0).toDouble(),
      targetStatus: (json['targetStatus'] ?? pi['targetStatus'] ?? '').toString(),
      overtimeHours: strOvertimeHours,
      lateMarks: (json['lateMarks'] ?? pi['lateMarks'] ?? 0).toDouble(),
      lateDeduction: (json['lateDeduction'] ?? pi['lateDeduction'] ?? 0).toDouble(),
      otActualHours: (json['otActualHours'] ?? pi['otActualHours'] ?? 0).toDouble(),
      otPayableHours: (json['otPayableHours'] ?? pi['otPayableHours'] ?? 0).toDouble(),
      otPayout: (json['otPayout'] ?? pi['overtime'] ?? json['overtime'] ?? 0).toDouble(),
      attendanceSummary: attSummary.isNotEmpty ? attSummary : null,
      salaryBreakdown: sBreakdown,
      status: (json['status'] ?? 'GENERATED').toString(),
      downloadUrl:
          json['pdfUrl']?.toString() ?? json['downloadUrl']?.toString(),
      slipNumber: slipNum,
      paymentMode: pMode,
      paymentReference: pRef,
      bankDetails: bDetails,
      employeeDetails: emp,
    );
  }
}

/// Representation of an Employee's Commission Summary
class CommissionSummaryItem {
  final double currentMonthCommission;
  final double totalEarnedCommission;
  final double commissionRatePct;
  final List<Map<String, dynamic>> salesEntries;

  CommissionSummaryItem({
    required this.currentMonthCommission,
    required this.totalEarnedCommission,
    required this.commissionRatePct,
    this.salesEntries = const [],
  });

  factory CommissionSummaryItem.fromJson(Map<String, dynamic> json) {
    return CommissionSummaryItem(
      currentMonthCommission:
          (json['currentMonth'] ?? json['currentMonthCommission'] ?? 0.0)
              .toDouble(),
      totalEarnedCommission:
          (json['totalEarned'] ?? json['totalEarnedCommission'] ?? 0.0)
              .toDouble(),
      commissionRatePct: (json['commissionRate'] ?? json['rate'] ?? 5.0)
          .toDouble(),
      salesEntries: json['sales'] != null
          ? List<Map<String, dynamic>>.from(json['sales'])
          : [],
    );
  }
}
