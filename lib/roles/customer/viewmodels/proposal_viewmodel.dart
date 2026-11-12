import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/roles/customer/models/proposal_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/current_customer_viewmodel.dart';

final proposalsProvider =
    NotifierProvider<ProposalsViewModel, List<ProposalModel>>(() {
      return ProposalsViewModel();
    });

class ProposalsViewModel extends Notifier<List<ProposalModel>> {
  @override
  List<ProposalModel> build() {
    final customerNameAsync = ref.watch(currentCustomerNameProvider);
    final customerName =
        (customerNameAsync.asData?.value ?? customerNameAsync.value ?? '')
            .trim()
            .toLowerCase();
    if (customerName.isEmpty) return [];

    final all = _mockProposals();
    return all
        .where((p) => p.customerName.toLowerCase() == customerName)
        .toList();
  }

  List<ProposalModel> _mockProposals() {
    return [
      ProposalModel(
        id: 'prop-cf-001',
        proposalNo: 'QB-2026-CF-01',
        customerId: 'T001',
        leadId: 'lead-001',
        customerName: 'Care Fitness Gym',
        contactPerson: 'Rahul Sharma',
        mobile: '9820112345',
        email: 'info@carefitness.com',
        date: '15 Aug 2026',
        items: [
          ProposalItemModel(
            id: 'pi-cf-001',
            name: 'Growth Plan (12 Reels, 8 Posts, Meta Ads)',
            quantity: 1,
            planType: 'Monthly',
            unitPrice: 35000,
          ),
        ],
        subtotal: 35000,
        discount: 0,
        gstPercent: 18,
        gstAmount: 6300,
        netTotal: 41300,
        status: 'SENT',
        createdAt: '2026-08-15T10:00:00.000Z',
      ),
      ProposalModel(
        id: 'prop-abc-001',
        proposalNo: 'QB-2026-ABC-01',
        customerId: 'T002',
        leadId: 'lead-002',
        customerName: 'ABC Fitness',
        contactPerson: 'Vikram Mehta',
        mobile: '9820099887',
        email: 'contact@abcfitness.com',
        date: '16 Aug 2026',
        items: [
          ProposalItemModel(
            id: 'pi-abc-001',
            name: 'Pro Package (16 Reels, Drone Shoot)',
            quantity: 1,
            planType: 'Monthly',
            unitPrice: 50000,
          ),
        ],
        subtotal: 50000,
        discount: 0,
        gstPercent: 18,
        gstAmount: 9000,
        netTotal: 59000,
        status: 'ACCEPTED',
        createdAt: '2026-08-16T10:00:00.000Z',
      ),
      ProposalModel(
        id: 'prop-001',
        proposalNo: 'QB-2026-089',
        customerId: '',
        leadId: '',
        customerName: 'Tata Consultancy Services',
        contactPerson: 'Rajesh Gopinathan',
        mobile: '9800000001',
        email: 'rajesh@tcs.com',
        date: '16 Aug 2026',
        items: [
          ProposalItemModel(
            id: 'pi-s-001',
            name: 'Enterprise CRM Cloud Solution',
            quantity: 1,
            planType: 'Yearly',
            unitPrice: 75000,
          ),
          ProposalItemModel(
            id: 'pi-s-002',
            name: '10 User Seats',
            quantity: 10,
            planType: 'Yearly',
            unitPrice: 1000,
          ),
        ],
        subtotal: 85000,
        discount: 0,
        gstPercent: 18,
        gstAmount: 15300,
        netTotal: 100300,
        status: 'SENT',
        createdAt: '2026-08-16T10:00:00.000Z',
      ),
      ProposalModel(
        id: 'prop-002',
        proposalNo: 'QB-2026-088',
        customerId: '',
        leadId: '',
        customerName: 'Reliance Digital Retail',
        contactPerson: 'Mukesh Ambani',
        mobile: '9800000002',
        email: 'info@reliance.com',
        date: '15 Aug 2026',
        items: [
          ProposalItemModel(
            id: 'pi-s-003',
            name: 'Custom POS Sync Bridge',
            quantity: 1,
            planType: 'One-time',
            unitPrice: 125000,
          ),
        ],
        subtotal: 125000,
        discount: 0,
        gstPercent: 18,
        gstAmount: 22500,
        netTotal: 147500,
        status: 'ACCEPTED',
        createdAt: '2026-08-15T10:00:00.000Z',
      ),
      ProposalModel(
        id: 'prop-003',
        proposalNo: 'QB-2026-085',
        customerId: '',
        leadId: '',
        customerName: 'Infosys Technologies Hub',
        contactPerson: 'Salil Parekh',
        mobile: '9800000003',
        email: 'salil@infosys.com',
        date: '12 Aug 2026',
        items: [
          ProposalItemModel(
            id: 'pi-s-004',
            name: 'Field Workforce GPS Attendance',
            quantity: 1,
            planType: 'Yearly',
            unitPrice: 65000,
          ),
        ],
        subtotal: 65000,
        discount: 0,
        gstPercent: 18,
        gstAmount: 11700,
        netTotal: 76700,
        status: 'NEGOTIATION',
        createdAt: '2026-08-12T10:00:00.000Z',
      ),
      ProposalModel(
        id: 'prop-004',
        proposalNo: 'QB-2026-081',
        customerId: '',
        leadId: '',
        customerName: 'HCL Enterprise Software',
        contactPerson: 'Roshni Nadar',
        mobile: '9800000004',
        email: 'roshni@hcl.com',
        date: '10 Aug 2026',
        items: [
          ProposalItemModel(
            id: 'pi-s-005',
            name: 'Annual Software Maintenance SLA',
            quantity: 1,
            planType: 'Yearly',
            unitPrice: 45000,
          ),
        ],
        subtotal: 45000,
        discount: 0,
        gstPercent: 18,
        gstAmount: 8100,
        netTotal: 53100,
        status: 'DRAFT',
        createdAt: '2026-08-10T10:00:00.000Z',
      ),
    ];
  }

  void addProposal(ProposalModel proposal) {
    state = [proposal, ...state];
  }

  void updateProposal(ProposalModel proposal) {
    state = [
      for (final p in state)
        if (p.id == proposal.id) proposal else p,
    ];
  }

  void deleteProposal(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void updateStatus(String id, String status) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(status: status) else p,
    ];
  }

  void duplicateProposal(ProposalModel prop) {
    final count = state.length + 1;
    final newNo = 'QB-2026-${(89 + count).toString().padLeft(3, '0')}';
    final newId =
        'prop-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final duplicated = prop.copyWith(
      id: newId,
      proposalNo: newNo,
      status: 'DRAFT',
      createdAt: DateTime.now().toIso8601String(),
    );
    state = [duplicated, ...state];
  }

  String get nextProposalNo {
    final count = state.length + 1;
    return 'QB-2026-${(89 + count).toString().padLeft(3, '0')}';
  }

  List<ProposalModel> filterByStatus(String status) {
    if (status == 'ALL') return state;
    return state.where((p) => p.status == status).toList();
  }
}
