import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import '../services/employee_api_service.dart';

class MonthlyReportsView extends ConsumerStatefulWidget {
  const MonthlyReportsView({super.key});

  @override
  ConsumerState<MonthlyReportsView> createState() => _MonthlyReportsViewState();
}

class _MonthlyReportsViewState extends ConsumerState<MonthlyReportsView> {
  bool loading = true;
  String error = '';
  List reports = [];
  Map commission = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = ''; });
    try {
      final body = await ref.read(employeeApiServiceProvider).monthlyReports();
      setState(() {
        reports = body['reports'] is List ? body['reports'] as List : [];
        commission = body['commission'] is Map ? Map<String, dynamic>.from(body['commission'] as Map) : {};
        loading = false;
      });
    } catch (_) {
      setState(() { error = 'Unable to load monthly reports.'; loading = false; });
    }
  }

  Future<void> openReport(int id) async {
    final url = await ref.read(employeeApiServiceProvider).monthlyReportUrl(id);
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: 'Monthly Reports', showBackButton: true),
      body: loading ? const Center(child: CircularProgressIndicator()) : error.isNotEmpty ? Center(child: Text(error)) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Commission earned ${commission['netEarned'] ?? 0} · paid ${commission['paid'] ?? 0} · outstanding ${commission['outstanding'] ?? 0}', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (reports.isEmpty) const Text('No monthly PDFs have been generated yet.'),
          ...reports.map((report) => Card(child: ListTile(
            title: Text(report['fileName']?.toString() ?? 'Report'),
            subtitle: Text('${report['reportType']} · ${report['status']}'),
            onTap: () => openReport(int.parse('${report['id']}')),
          ))),
        ],
      ),
    );
  }
}
