import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/roles/employee/models/package_model.dart';

final packagesProvider =
    NotifierProvider<PackagesViewModel, List<PackageModel>>(() {
      return PackagesViewModel();
    });

class PackagesViewModel extends Notifier<List<PackageModel>> {
  @override
  List<PackageModel> build() => _mockPackages();

  List<PackageModel> _mockPackages() {
    return [
      PackageModel(
        id: 'pkg-001',
        name: 'CRM Starter',
        description:
            'Essential CRM for small businesses. 5 user seats included.',
        duration: 12,
        durationType: 'Months',
        basePrice: 50000,
        gstPercent: 18,
        status: 'ACTIVE',
        createdAt: '2026-06-01T09:00:00.000Z',
        items: [
          PackageItemModel(
            id: 'pi-001-1',
            packageId: 'pkg-001',
            name: 'CRM Cloud',
            quantity: 1,
            planType: 'Yearly',
            unitPrice: 30000,
          ),
          PackageItemModel(
            id: 'pi-001-2',
            packageId: 'pkg-001',
            name: 'User Seats',
            quantity: 5,
            planType: 'Yearly',
            unitPrice: 4000,
          ),
        ],
      ),
      PackageModel(
        id: 'pkg-002',
        name: 'CRM Professional',
        description: 'Advanced CRM with work management and 10 user seats.',
        duration: 12,
        durationType: 'Months',
        basePrice: 80000,
        gstPercent: 18,
        status: 'ACTIVE',
        createdAt: '2026-06-01T09:00:00.000Z',
        items: [
          PackageItemModel(
            id: 'pi-002-1',
            packageId: 'pkg-002',
            name: 'CRM Cloud',
            quantity: 1,
            planType: 'Yearly',
            unitPrice: 50000,
          ),
          PackageItemModel(
            id: 'pi-002-2',
            packageId: 'pkg-002',
            name: 'User Seats',
            quantity: 10,
            planType: 'Yearly',
            unitPrice: 3000,
          ),
        ],
      ),
      PackageModel(
        id: 'pkg-003',
        name: 'CRM Enterprise',
        description: 'Full suite CRM. Work tracking, attendance, GPS, reports.',
        duration: 24,
        durationType: 'Months',
        basePrice: 150000,
        gstPercent: 18,
        status: 'ACTIVE',
        createdAt: '2026-06-01T09:00:00.000Z',
        items: [
          PackageItemModel(
            id: 'pi-003-1',
            packageId: 'pkg-003',
            name: 'CRM Cloud',
            quantity: 1,
            planType: 'Yearly',
            unitPrice: 80000,
          ),
          PackageItemModel(
            id: 'pi-003-2',
            packageId: 'pkg-003',
            name: 'User Seats',
            quantity: 20,
            planType: 'Yearly',
            unitPrice: 3500,
          ),
          PackageItemModel(
            id: 'pi-003-3',
            packageId: 'pkg-003',
            name: 'Task Management',
            quantity: 1,
            planType: 'Yearly',
            unitPrice: 0,
          ),
          PackageItemModel(
            id: 'pi-003-4',
            packageId: 'pkg-003',
            name: 'GPS Attendance',
            quantity: 1,
            planType: 'Yearly',
            unitPrice: 0,
          ),
        ],
      ),
    ];
  }

  void addPackage(PackageModel pkg) {
    state = [...state, pkg];
  }

  void updatePackage(PackageModel pkg) {
    state = [
      for (final p in state)
        if (p.id == pkg.id) pkg else p,
    ];
  }

  void deletePackage(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void toggleStatus(String id) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(status: p.isActive ? 'INACTIVE' : 'ACTIVE')
        else
          p,
    ];
  }

  void duplicatePackage(PackageModel pkg) {
    final newId = nextId;
    final duplicated = pkg.copyWith(
      id: newId,
      name: '${pkg.name} (Copy)',
      createdAt: DateTime.now().toIso8601String(),
    );
    state = [...state, duplicated];
  }

  List<PackageModel> get activePackages =>
      state.where((p) => p.isActive).toList();

  List<PackageModel> search(String query) {
    if (query.isEmpty) return state;
    return state.where((p) => p.matchesQuery(query)).toList();
  }

  String get nextId {
    final count = state.length + 1;
    return 'pkg-${count.toString().padLeft(3, '0')}';
  }
}
