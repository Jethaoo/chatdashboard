import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_session_model.dart';
import '../models/message_model.dart';
import '../utils/outgoing_message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static int get maxMessageLength => kMaxOutgoingMessageLength;

  /// One in-flight [getOrCreateSession] per customer avoids duplicate
  /// "active" sessions from concurrent calls on the same client.
  static final Map<String, Future<String>> _activeSessionLocks = {};

  // CUSTOMER: Get or create their session
  Future<String> getOrCreateSession(String customerId, String customerEmail) {
    return _activeSessionLocks.putIfAbsent(
      customerId,
      () => _getOrCreateSessionOnce(customerId, customerEmail).whenComplete(() {
        _activeSessionLocks.remove(customerId);
      }),
    );
  }

  Future<String> _getOrCreateSessionOnce(
    String customerId,
    String customerEmail,
  ) async {
    final query = await _firestore
        .collection('sessions')
        .where('customerId', isEqualTo: customerId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }

    final docRef = await _firestore.collection('sessions').add({
      'customerId': customerId,
      'customerEmail': customerEmail,
      'status': 'active',
      'lastActivity': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// One-shot read (avoids long-lived native listeners on Windows desktop, where
  /// `.snapshots()` has been linked to ucrtbase / 0xc0000409 crashes for some setups).
  Future<List<ChatSessionModel>> fetchSessionsOnce() async {
    final snapshot = await _firestore
        .collection('sessions')
        .orderBy('lastActivity', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ChatSessionModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<MessageModel>> fetchMessagesOnce(String sessionId) async {
    final snapshot = await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ADMIN: Stream all sessions
  Stream<List<ChatSessionModel>> streamSessions() {
    return _firestore
        .collection('sessions')
        .orderBy('lastActivity', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatSessionModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // BOTH: Stream messages in a session
  Stream<List<MessageModel>> streamMessages(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // BOTH: Send a message
  Future<void> sendMessage(
    String sessionId,
    String text,
    String senderId,
    String senderName,
  ) async {
    final body = normalizeOutgoingMessageBody(text);
    if (body.isEmpty) return;

    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .add({
          'text': body,
          'senderId': senderId,
          'senderName': senderName,
          'timestamp': FieldValue.serverTimestamp(),
        });

    await _firestore.collection('sessions').doc(sessionId).update({
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  // ADMIN: Resolve a session
  Future<void> resolveSession(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': 'resolved',
    });
  }

  // ADMIN: Reopen a resolved session
  Future<void> reopenSession(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': 'active',
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }
}
