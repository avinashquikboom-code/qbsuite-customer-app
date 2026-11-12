import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_service.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/customer_card.dart';

class CustomersView extends ConsumerStatefulWidget {
  final bool showBackButton;
  final String title;

  const CustomersView({
    super.key,
    this.showBackButton = false,
    this.title = 'Customers',
  });

  @override
  ConsumerState<CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends ConsumerState<CustomersView>
    with WidgetsBindingObserver {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // CRM lifecycle progression tabs: All -> Active -> Inactive -> Upcoming
  final List<String> _tabs = ['All', 'Active', 'Inactive', 'Upcoming'];
  String _selectedTab = 'All';

  static const int _pageSize = 20;
  int _displayedCount = 20;

  String get _apiStatus {
    switch (_selectedTab) {
      case 'Active':
        return 'ACTIVE';
      case 'Inactive':
        return 'INACTIVE';
      case 'Upcoming':
        return 'UPCOMING';
      default:
        return 'ALL';
    }
  }

  CustomersDirectoryQuery get _directoryQuery => CustomersDirectoryQuery(
        status: _apiStatus,
        search: _searchCtrl.text,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.hasClients &&
        _scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200) {
      if (mounted) {
        setState(() {
          _displayedCount += _pageSize;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint(
        '[CUSTOMERS_VIEW] App resumed: refreshing customers from backend...',
      );
      invalidateCustomersDirectory(ref);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersDirectoryProvider(_directoryQuery));
    final searchQuery = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppAppBar(
        title: widget.title,
        showBackButton: widget.showBackButton,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. Search Bar ───────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) {
                  setState(() {
                    _displayedCount = _pageSize;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by client name, business, account…',
                  hintStyle: GoogleFonts.outfit(
                    color: AppColors.textPlaceholder,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Remix.search_2_line,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Remix.close_circle_line,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _displayedCount = _pageSize;
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.scaffoldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            // ── 2. Tabs Row (Upcoming, Inactive, Active) ───────────────
            customersAsync.when(
              skipLoadingOnReload: true,
              data: (data) => _buildFilterTabs(data.customers, data.counts),
              loading: () => _buildFilterTabs([], const {
                'upcoming': 0,
                'inactive': 0,
                'active': 0,
                'all': 0,
              }),
              error: (_, _) => _buildFilterTabs([], const {
                'upcoming': 0,
                'inactive': 0,
                'active': 0,
                'all': 0,
              }),
            ),

            const Divider(height: 1, color: AppColors.borderLight),

            // ── 3. Customers List ────────────────────────────────────────
            Expanded(
              child: customersAsync.when(
                skipLoadingOnReload: true,
                data: (data) {
                  // Server returns the selected lifecycle bucket; search is also applied server-side.
                  final displayList = data.customers;

                  if (displayList.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        invalidateCustomersDirectory(ref);
                        await ref.read(
                          customersDirectoryProvider(_directoryQuery).future,
                        );
                      },
                      color: AppColors.primary,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: _buildEmptyState(searchQuery),
                          ),
                        ],
                      ),
                    );
                  }

                  final visibleItems = displayList
                      .take(_displayedCount)
                      .toList();
                  final hasMore = displayList.length > visibleItems.length;

                  return RefreshIndicator(
                    onRefresh: () async {
                      invalidateCustomersDirectory(ref);
                      await ref.read(
                        customersDirectoryProvider(_directoryQuery).future,
                      );
                    },
                    color: AppColors.primary,
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.all(16),
                      itemCount: visibleItems.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == visibleItems.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          );
                        }

                        final customer = visibleItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CustomerCard(customer: customer),
                        );
                      },
                    ),
                  );
                },
                loading: () => const SkeletonList(count: 5),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Remix.error_warning_line,
                          size: 44,
                          color: AppColors.textPlaceholder,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load customers',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              ref.refresh(customersDirectoryProvider(_directoryQuery)),
                          icon: const Icon(Remix.refresh_line, size: 16),
                          label: Text(
                            'Retry',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(List<dynamic> customers, Map<String, int> counts) {
    final tabCounts = {
      'All': counts['all'] ?? customers.length,
      'Active': counts['active'] ?? 0,
      'Inactive': counts['inactive'] ?? 0,
      'Upcoming': counts['upcoming'] ?? 0,
    };

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _tabs.map((tab) {
            final isSelected = _selectedTab == tab;
            final count = tabCounts[tab] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                key: ValueKey('filter_tab_$tab'),
                onTap: () {
                  setState(() {
                    _selectedTab = tab;
                    _displayedCount = _pageSize;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tab,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppColors.borderLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String searchQuery) {
    if (searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Remix.search_line,
                size: 44,
                color: AppColors.textPlaceholder,
              ),
              const SizedBox(height: 12),
              Text(
                'No Results for "$searchQuery"',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Try checking the spelling or search with a different keyword.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    String title;
    String description;
    IconData icon;

    switch (_selectedTab) {
      case 'Active':
        title = 'No Active Customers';
        description =
            'Customers with an active subscription plan will appear here.';
        icon = Remix.user_star_line;
        break;
      case 'Upcoming':
        title = 'No Upcoming Calls';
        description =
            'Customers with a scheduled or pending final call will appear here.';
        icon = Remix.phone_find_line;
        break;
      case 'Inactive':
        title = 'No Inactive Customers';
        description =
            'Customers without a plan or with an expired subscription will appear here.';
        icon = Remix.user_unfollow_line;
        break;
      case 'All':
      default:
        title = 'No Customers';
        description = 'No customer records found in your CRM.';
        icon = Remix.user_search_line;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: AppColors.textPlaceholder),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
