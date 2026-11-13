import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/capture_history.dart';
import '../../services/data_capture_records_service.dart';
import '../../services/data_capture_service.dart';
import 'data_capture_records_screen.dart';

class DataCaptureHistoryScreen extends StatefulWidget {
  const DataCaptureHistoryScreen({super.key});
  @override
  State<DataCaptureHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<DataCaptureHistoryScreen> {
  final _service = DataCaptureService();
  final _search = TextEditingController();
  Timer? _debounce;
  DateTimeRange? _dates;
  CaptureHistoryPage? _data;
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load([int page = 1]) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dates = _dates;
      final result = await _service.getHistory(
        page: page,
        search: _search.text,
        from: dates?.start,
        to: dates == null
            ? null
            : DateTime(dates.end.year, dates.end.month, dates.end.day + 1),
      );
      if (mounted && generation == _generation) setState(() => _data = result);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = dataCaptureError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _chooseDates() async {
    final now = DateTime.now();
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dates,
    );
    if (!mounted || dates == null) return;
    setState(() => _dates = dates);
    await _load();
  }

  String _date(DateTime value) => MaterialLocalizations.of(context).formatMediumDate(value);

  Widget _session(CaptureHistorySession session) {
    final color = session.status == 'FAILED'
        ? Colors.red
        : session.status == 'PARTIALLY_COMPLETED'
        ? Colors.orange.shade800
        : AppColors.primaryDark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.keyword,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(session.location),
            const SizedBox(height: 6),
            Text(
              '${_date(session.createdAt)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(session.createdAt))}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Text(
              session.statusLabel,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text('Found: ${session.found ?? 'Unavailable'}'),
                Text('Captured: ${session.captured}'),
                Text('Extracted: ${session.captured}'),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DataCaptureRecordsScreen(
                    jobId: session.jobId,
                    fromHistory: true,
                  ),
                ),
              ),
              child: const Text('View captured businesses'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Capture History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search query or location',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 350),
                        () => _load(),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _chooseDates,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _dates == null
                              ? 'Filter dates'
                              : '${_date(_dates!.start)} – ${_date(_dates!.end)}',
                        ),
                      ),
                      if (_dates != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _dates = null);
                            _load();
                          },
                          child: const Text('Clear dates'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => _load(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Icon(Icons.error_outline_rounded, size: 44, color: Colors.red.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _load(data?.page ?? 1),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else if (data == null || data.sessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              size: 52,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No capture history found.',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_search.text.trim().isNotEmpty || _dates != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Try adjusting your search query or date range filters.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      )
                    else ...[
                      ...data.sessions.map(_session),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        children: [
                          TextButton(
                            onPressed: data.page > 1
                                ? () => _load(data.page - 1)
                                : null,
                            child: const Text('Previous'),
                          ),
                          Text('Page ${data.page} of ${data.totalPages}'),
                          TextButton(
                            onPressed: data.page < data.totalPages
                                ? () => _load(data.page + 1)
                                : null,
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
