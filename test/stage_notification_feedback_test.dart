import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickboom_crm_customer/shared/utils/stage_notification_feedback.dart';

void main() {
  testWidgets(
    'shows mapped template and refreshes delivery status when stage changes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      key: const Key('details-send'),
                      onPressed: () => showStageChannelFeedback(
                        context,
                        stageId: 31,
                        stageName: 'Details Send',
                        whatsapp: {
                          'status': 'QUEUED',
                          'configurationStatus': 'CONFIGURED',
                          'templateName': 'lead_details_sent',
                        },
                        email: {
                          'status': 'NOT_CONFIGURED',
                          'configurationStatus': 'NOT_CONFIGURED',
                        },
                      ),
                      child: const Text('Details Send'),
                    ),
                    TextButton(
                      key: const Key('visit-schedule'),
                      onPressed: () => showStageChannelFeedback(
                        context,
                        stageId: 42,
                        stageName: 'Visit Schedule',
                        whatsapp: {
                          'status': 'PENDING_APPROVAL',
                          'configurationStatus': 'PENDING_APPROVAL',
                          'templateName': 'visit_notice_v2',
                        },
                        email: {
                          'status': 'SENT',
                          'configurationStatus': 'CONFIGURED',
                          'templateName': 'visit_email',
                        },
                      ),
                      child: const Text('Visit Schedule'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('details-send')));
      await tester.pump();
      expect(find.text('Stage: Details Send'), findsOneWidget);
      expect(
        find.textContaining('Template: lead_details_sent'),
        findsOneWidget,
      );
      expect(find.textContaining('Email: NOT_CONFIGURED'), findsOneWidget);

      await tester.tap(find.byKey(const Key('visit-schedule')));
      await tester.pump();
      expect(find.text('Stage: Visit Schedule'), findsOneWidget);
      expect(find.textContaining('Stage: Details Send'), findsNothing);
      expect(find.textContaining('Template: visit_notice_v2'), findsOneWidget);
      expect(find.textContaining('WhatsApp: PENDING_APPROVAL'), findsOneWidget);
      expect(find.textContaining('Email: SENT'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    },
  );
}
