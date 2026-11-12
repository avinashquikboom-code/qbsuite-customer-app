import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/models/permission_model.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/shared/models/lead_model.dart';
import 'package:quickboom_crm_customer/shared/views/leads/lead_details_view.dart';

class _CaptureAdapter implements HttpClientAdapter {
  final FutureOr<ResponseBody> Function(RequestOptions) handler;
  _CaptureAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Object data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    PermissionManager.instance.setPermissions([
      const UserPermission(module: 'LEADS', action: 'VIEW'),
      const UserPermission(module: 'LEADS', action: 'CHANGE_STAGE'),
      const UserPermission(module: 'VISITS', action: 'CREATE'),
      const UserPermission(module: 'VISITS', action: 'VIEW'),
    ], role: 'BPO');
  });

  tearDown(() {
    PermissionManager.instance.clear();
  });

  group('BPO Visitor Assignment & Visits Tab UI Tests', () {
    test('LeadModel correctly parses visits and serializes to JSON', () {
      final json = {
        'id': '101',
        'companyName': 'Star Tech Inc',
        'status': 'VISIT_SCHEDULED',
        'source': 'DATA_CAPTURE',
        'createdFrom': 'MOBILE_APP',
        'visits': [
          {
            'id': '501',
            'customerName': 'Star Tech Inc',
            'purpose': 'Product Demonstration',
            'date': '2026-10-30T10:00:00.000Z',
            'time': '10:00 AM',
            'location': 'BKC, Mumbai',
            'status': 'SCHEDULED',
            'assignedEmployee': 'Rajesh Sharma',
            'notes': 'Interested in CRM modules',
            'createdAt': '2026-10-28T12:00:00.000Z',
          },
        ],
      };

      final lead = LeadModel.fromJson(json);
      expect(lead.visits.length, 1);
      expect(lead.visits.first.id, '501');
      expect(lead.visits.first.assignedEmployee, 'Rajesh Sharma');
      expect(lead.visits.first.purpose, 'Product Demonstration');
      expect(lead.visits.first.status, 'SCHEDULED');

      final serialized = lead.toJson();
      expect(serialized['visits'], isA<List>());
      expect((serialized['visits'] as List).length, 1);
    });

    testWidgets('Renders Visits tab with Schedule Visit button when no visits scheduled', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const emptyLead = LeadModel(
        id: '202',
        companyName: 'Apex Innovations',
        status: 'NEW',
        source: 'MANUAL',
        createdFrom: 'ADMIN_PANEL',
        visits: [],
      );

      ApiClient().dio.httpClientAdapter = _CaptureAdapter((options) {
        if (options.path.contains('/stages')) {
          return _jsonBody({'data': []});
        }
        if (options.path.contains('/notes')) {
          return _jsonBody({'data': []});
        }
        return _jsonBody({'data': emptyLead.toJson()});
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LeadDetailsView(leadId: '202', initialLead: emptyLead),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Visits tab and tap it
      final visitsTab = find.text('Visits');
      expect(visitsTab, findsOneWidget);
      await tester.tap(visitsTab);
      await tester.pumpAndSettle();

      // Verify empty state and "Schedule Visit" button are rendered
      expect(find.text('No Visits Scheduled'), findsOneWidget);
      expect(find.text('Visits scheduled for this lead will appear here.'), findsOneWidget);
      expect(find.text('Schedule Visit'), findsOneWidget);
    });

    testWidgets('Renders scheduled visit cards when lead has visits', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const leadWithVisit = LeadModel(
        id: '303',
        companyName: 'Omega Solutions',
        status: 'VISIT_SCHEDULED',
        source: 'MANUAL',
        createdFrom: 'ADMIN_PANEL',
        visits: [
          LeadVisitModel(
            id: '701',
            customerName: 'Omega Solutions',
            purpose: 'Contract Review & Demo',
            date: '2026-10-31',
            time: '02:30 PM',
            location: 'Sector 5, Salt Lake',
            status: 'SCHEDULED',
            assignedEmployee: 'Anil Kumar',
            notes: 'High priority client',
            createdAt: '2026-10-28T10:00:00.000Z',
          ),
        ],
      );

      ApiClient().dio.httpClientAdapter = _CaptureAdapter((options) {
        if (options.path.contains('/stages')) {
          return _jsonBody({'data': []});
        }
        if (options.path.contains('/notes')) {
          return _jsonBody({'data': []});
        }
        return _jsonBody({'data': leadWithVisit.toJson()});
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LeadDetailsView(leadId: '303', initialLead: leadWithVisit),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Visits tab
      await tester.tap(find.text('Visits'));
      await tester.pumpAndSettle();

      // Verify visit details
      expect(find.text('Field Visits (1)'), findsOneWidget);
      expect(find.text('Contract Review & Demo'), findsOneWidget);
      expect(find.text('Anil Kumar'), findsOneWidget);
      expect(find.text('Sector 5, Salt Lake'), findsOneWidget);
      expect(find.text('Scheduled'), findsWidgets);
      expect(find.text('High priority client'), findsOneWidget);
    });
  });
}
