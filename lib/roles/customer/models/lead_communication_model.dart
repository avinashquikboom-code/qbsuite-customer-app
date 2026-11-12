import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

enum LeadCommChannel {
  email,
  whatsapp;

  static LeadCommChannel fromString(String? val) {
    if (val?.toUpperCase() == 'EMAIL') return LeadCommChannel.email;
    return LeadCommChannel.whatsapp;
  }
}

enum LeadCommDirection {
  outbound,
  inbound;

  static LeadCommDirection fromString(String? val) {
    if (val?.toUpperCase() == 'INBOUND') return LeadCommDirection.inbound;
    return LeadCommDirection.outbound;
  }
}

enum LeadCommStatus {
  queued,
  sent,
  delivered,
  read,
  received,
  failed;

  static LeadCommStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'QUEUED':
        return LeadCommStatus.queued;
      case 'DELIVERED':
        return LeadCommStatus.delivered;
      case 'READ':
        return LeadCommStatus.read;
      case 'RECEIVED':
        return LeadCommStatus.received;
      case 'FAILED':
        return LeadCommStatus.failed;
      case 'SENT':
      default:
        return LeadCommStatus.sent;
    }
  }

  String get label {
    switch (this) {
      case LeadCommStatus.queued:
        return 'Queued';
      case LeadCommStatus.sent:
        return 'Sent';
      case LeadCommStatus.delivered:
        return 'Delivered';
      case LeadCommStatus.read:
        return 'Read';
      case LeadCommStatus.received:
        return 'Received';
      case LeadCommStatus.failed:
        return 'Failed';
    }
  }

  Color get color {
    switch (this) {
      case LeadCommStatus.queued:
        return const Color(0xFFF59E0B); // Amber
      case LeadCommStatus.sent:
        return const Color(0xFF6B7280); // Gray
      case LeadCommStatus.delivered:
        return const Color(0xFF4B5563); // Slate
      case LeadCommStatus.read:
        return const Color(0xFF0284C7); // Vibrant Blue
      case LeadCommStatus.received:
        return const Color(0xFF10B981); // Emerald
      case LeadCommStatus.failed:
        return const Color(0xFFEF4444); // Red
    }
  }

  IconData get icon {
    switch (this) {
      case LeadCommStatus.queued:
        return Remix.time_line;
      case LeadCommStatus.sent:
        return Remix.check_line;
      case LeadCommStatus.delivered:
        return Remix.check_double_line;
      case LeadCommStatus.read:
        return Remix.check_double_fill;
      case LeadCommStatus.received:
        return Remix.arrow_down_line;
      case LeadCommStatus.failed:
        return Remix.error_warning_line;
    }
  }
}

class LeadCommunicationItem {
  final String id;
  final LeadCommChannel channel;
  final LeadCommDirection direction;
  final String action;
  final LeadCommStatus status;
  final String title;
  final String content;
  final String recipient;
  final String sender;
  final String? errorMessage;
  final String? providerMessageId;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const LeadCommunicationItem({
    required this.id,
    required this.channel,
    required this.direction,
    required this.action,
    required this.status,
    required this.title,
    required this.content,
    required this.recipient,
    required this.sender,
    this.errorMessage,
    this.providerMessageId,
    required this.createdAt,
    this.metadata,
  });

  factory LeadCommunicationItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString()).toLocal()
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return LeadCommunicationItem(
      id: json['id']?.toString() ?? '',
      channel: LeadCommChannel.fromString(json['channel']?.toString()),
      direction: LeadCommDirection.fromString(json['direction']?.toString()),
      action: json['action']?.toString() ?? '',
      status: LeadCommStatus.fromString(json['status']?.toString()),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      recipient: json['recipient']?.toString() ?? '',
      sender: json['sender']?.toString() ?? '',
      errorMessage: json['errorMessage']?.toString(),
      providerMessageId: json['providerMessageId']?.toString(),
      createdAt: parsedDate,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  bool get isFailed => status == LeadCommStatus.failed;
  bool get isEmail => channel == LeadCommChannel.email;
  bool get isWhatsApp => channel == LeadCommChannel.whatsapp;
  bool get isInbound => direction == LeadCommDirection.inbound;

  Color get channelColor =>
      isEmail ? const Color(0xFF4F46E5) : const Color(0xFF25D366);

  IconData get channelIcon => isEmail ? Remix.mail_line : Remix.whatsapp_line;
}

class LeadCommunicationSummary {
  final int totalCommunications;
  final int totalEmails;
  final int totalWhatsApp;
  final DateTime? lastContactAt;
  final LeadCommChannel? lastChannel;
  final LeadCommStatus? lastStatus;

  const LeadCommunicationSummary({
    required this.totalCommunications,
    required this.totalEmails,
    required this.totalWhatsApp,
    this.lastContactAt,
    this.lastChannel,
    this.lastStatus,
  });

  factory LeadCommunicationSummary.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['lastContactAt'] != null) {
      try {
        parsedDate = DateTime.parse(json['lastContactAt'].toString()).toLocal();
      } catch (_) {}
    }

    return LeadCommunicationSummary(
      totalCommunications: json['totalCommunications'] is int
          ? json['totalCommunications']
          : int.tryParse(json['totalCommunications']?.toString() ?? '0') ?? 0,
      totalEmails: json['totalEmails'] is int
          ? json['totalEmails']
          : int.tryParse(json['totalEmails']?.toString() ?? '0') ?? 0,
      totalWhatsApp: json['totalWhatsApp'] is int
          ? json['totalWhatsApp']
          : int.tryParse(json['totalWhatsApp']?.toString() ?? '0') ?? 0,
      lastContactAt: parsedDate,
      lastChannel: json['lastChannel'] != null
          ? LeadCommChannel.fromString(json['lastChannel'].toString())
          : null,
      lastStatus: json['lastStatus'] != null
          ? LeadCommStatus.fromString(json['lastStatus'].toString())
          : null,
    );
  }
}

class LeadCommunicationsResponse {
  final int leadId;
  final LeadCommunicationSummary summary;
  final List<LeadCommunicationItem> communications;

  const LeadCommunicationsResponse({
    required this.leadId,
    required this.summary,
    required this.communications,
  });

  factory LeadCommunicationsResponse.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'])
        : <String, dynamic>{};
    final rawList = json['communications'] is List
        ? json['communications'] as List
        : [];

    return LeadCommunicationsResponse(
      leadId: json['leadId'] is int
          ? json['leadId']
          : int.tryParse(json['leadId']?.toString() ?? '0') ?? 0,
      summary: LeadCommunicationSummary.fromJson(rawSummary),
      communications: rawList
          .map(
            (item) =>
                LeadCommunicationItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class WhatsAppTemplateModel {
  final String key;
  final String templateName;
  final String title;
  final String name;
  final String body;

  const WhatsAppTemplateModel({
    required this.key,
    required this.templateName,
    required this.title,
    required this.name,
    required this.body,
  });

  factory WhatsAppTemplateModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppTemplateModel(
      key: json['key']?.toString() ?? '',
      templateName: json['templateName']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
    );
  }
}
