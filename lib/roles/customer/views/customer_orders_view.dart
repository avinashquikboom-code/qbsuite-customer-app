import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_plan_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_invoice_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_subscription_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/order_summary_card.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/invoice_preview_dialog.dart';
import 'customer_order_details_view.dart';

class CustomerOrdersView extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onOpenDrawer;

  const CustomerOrdersView({
    super.key,
    this.onNavigateToTab,
    this.onOpenDrawer,
  });

  @override
  ConsumerState<CustomerOrdersView> createState() => _CustomerOrdersViewState();
}

class _CustomerOrdersViewState extends ConsumerState<CustomerOrdersView> {
  int _selectedMainTab = 0; // 0: Orders, 1: Invoices
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, PAID, PENDING, MONTHLY, YEARLY

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatPrice(double amount) {
    final intVal = amount.round();
    final str = intVal.toString();
    if (str.length <= 3) return str;

    final lastThree = str.substring(str.length - 3);
    var remaining = str.substring(0, str.length - 3);
    final chunks = <String>[];
    while (remaining.length > 2) {
      chunks.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      chunks.insert(0, remaining);
    }
    return '${chunks.join(',')},$lastThree';
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionManagerProvider);
    final canOrders = perms.customerCan('CUSTOMER_ORDERS', 'VIEW');
    final canInvoices = perms.customerCan('CUSTOMER_INVOICES', 'VIEW');
    if (_selectedMainTab == 0 && !canOrders && canInvoices) {
      _selectedMainTab = 1;
    } else if (_selectedMainTab == 1 && !canInvoices && canOrders) {
      _selectedMainTab = 0;
    }

    if (!canOrders && !canInvoices) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: Navigator.canPop(context),
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Remix.arrow_left_line, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Text(
            'Orders & Invoices',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Remix.menu_line, color: AppColors.textPrimary),
              tooltip: 'Open Menu',
              onPressed:
                  widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Remix.lock_line,
                    size: 40,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have permission to view Orders or Invoices. Please contact your administrator if you need access.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ordersAsync = ref.watch(customerOrdersProvider);
    final invoicesAsync = ref.watch(customerInvoicesProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Orders & Invoices',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Remix.menu_line, color: AppColors.textPrimary),
            tooltip: 'Open Menu',
            onPressed:
                widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_selectedMainTab == 0) {
            await ref.read(customerOrdersProvider.notifier).refresh();
          } else {
            await ref.read(customerInvoicesProvider.notifier).refresh();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Top Tab (Orders vs Invoices)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    if (canOrders)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMainTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedMainTab == 0
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedMainTab == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Remix.file_list_3_line,
                                    size: 15,
                                    color: _selectedMainTab == 0
                                        ? AppColors.primaryDark
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Orders',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: _selectedMainTab == 0
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: _selectedMainTab == 0
                                          ? AppColors.primaryDark
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (canInvoices)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMainTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedMainTab == 1
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedMainTab == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Remix.bill_line,
                                    size: 15,
                                    color: _selectedMainTab == 1
                                        ? AppColors.primaryDark
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Invoices',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: _selectedMainTab == 1
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: _selectedMainTab == 1
                                          ? AppColors.primaryDark
                                          : AppColors.textSecondary,
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

              const SizedBox(height: 14),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: _selectedMainTab == 0
                        ? 'Search by Order ID or Plan...'
                        : 'Search by Invoice Number...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textPlaceholder,
                    ),
                    prefixIcon: const Icon(
                      Remix.search_2_line,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Remix.close_circle_line, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Orders View Body
              if (_selectedMainTab == 0) ...[
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Orders'),
                      _buildFilterChip('PAID', 'Paid'),
                      _buildFilterChip('PENDING', 'Pending'),
                      _buildFilterChip('MONTHLY', 'Monthly'),
                      _buildFilterChip('YEARLY', 'Yearly'),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Orders List
                ordersAsync.when(
                  data: (orders) {
                    var filtered = orders.where((o) {
                      final matchesSearch =
                          _searchQuery.isEmpty ||
                          o.orderNumber.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          o.planName.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          );

                      bool matchesStatus = true;
                      if (_statusFilter == 'PAID') {
                        matchesStatus = o.isPaid;
                      } else if (_statusFilter == 'PENDING') {
                        matchesStatus = !o.isPaid;
                      } else if (_statusFilter == 'MONTHLY') {
                        matchesStatus =
                            o.billingCycle == SubscriptionBillingCycle.monthly;
                      } else if (_statusFilter == 'YEARLY') {
                        matchesStatus =
                            o.billingCycle == SubscriptionBillingCycle.yearly;
                      }

                      return matchesSearch && matchesStatus;
                    }).toList();

                    if (filtered.isEmpty) {
                      return _buildEmptyOrdersState();
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final order = filtered[index];
                        return OrderSummaryCard(
                          order: order,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CustomerOrderDetailsView(order: order),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (err, stack) => _buildErrorState('Orders'),
                ),
              ] else ...[
                // Filter Chips for Invoices
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Invoices'),
                      _buildFilterChip('PAID', 'Paid'),
                      _buildFilterChip('PENDING', 'Pending'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Invoices List Body
                invoicesAsync.when(
                  data: (invoices) {
                    final filtered = invoices.where((inv) {
                      final matchesSearch =
                          _searchQuery.isEmpty ||
                          inv.invoiceNumber.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          inv.clientName.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          (inv.notes != null &&
                              inv.notes!.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ));

                      bool matchesStatus = true;
                      if (_statusFilter == 'PAID') {
                        matchesStatus = inv.isPaid;
                      } else if (_statusFilter == 'PENDING') {
                        matchesStatus = !inv.isPaid;
                      }

                      return matchesSearch && matchesStatus;
                    }).toList();

                    if (filtered.isEmpty) {
                      return _buildEmptyInvoicesState();
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final CustomerInvoice inv = filtered[index];
                        return InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => InvoicePreviewDialog(
                                invoice: inv,
                                documentTitle: 'TAX INVOICE',
                                documentNumber: inv.invoiceNumber,
                                displayAmount: inv.totalAmount,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderLight),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Remix.file_text_line,
                                          size: 16,
                                          color: AppColors.primaryDark,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          inv.invoiceNumber,
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: inv.isPaid
                                            ? AppColors.primaryLight
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        inv.status.toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: inv.isPaid
                                              ? AppColors.primaryDark
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(
                                  height: 1,
                                  color: AppColors.borderLight,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Issue Date',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          _formatDate(inv.issueDate),
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          inv.isPaid
                                              ? 'Total Paid'
                                              : 'Total Amount',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          '₹${_formatPrice(inv.totalAmount)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (err, stack) => _buildErrorState('Invoices'),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _statusFilter = key);
        },
        labelStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.borderLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  Widget _buildEmptyOrdersState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Remix.file_list_3_line,
              size: 48,
              color: AppColors.textPlaceholder,
            ),
            const SizedBox(height: 12),
            Text(
              'No Orders Found',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No matching subscription orders match your criteria.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  widget.onNavigateToTab?.call(1), // Go to plans tab
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Browse Plans',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInvoicesState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Remix.bill_line,
              size: 48,
              color: AppColors.textPlaceholder,
            ),
            const SizedBox(height: 12),
            Text(
              'No Invoices Available',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Final Tax Invoices are generated once full 100% plan payment is completed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String label) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Remix.error_warning_line,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to Load $label',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (_selectedMainTab == 0) {
                  ref.read(customerOrdersProvider.notifier).refresh();
                } else {
                  ref.read(customerInvoicesProvider.notifier).refresh();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
