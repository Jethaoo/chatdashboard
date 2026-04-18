import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSessionModel {
  final String id;
  final String customerId;
  final String customerEmail;
  final String status; // 'active', 'resolved'
  final DateTime lastActivity;

  ChatSessionModel({
    required this.id,
    required this.customerId,
    required this.customerEmail,
    required this.status,
    required this.lastActivity,
  });

  factory ChatSessionModel.fromMap(Map<String, dynamic> data, String id) {
    return ChatSessionModel(
      id: id,
      customerId: data['customerId'] ?? '',
      customerEmail: data['customerEmail'] ?? '',
      status: data['status'] ?? 'active',
      lastActivity: (data['lastActivity'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerEmail': customerEmail,
      'status': status,
      'lastActivity': Timestamp.fromDate(lastActivity),
    };
  }
}
