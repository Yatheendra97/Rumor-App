import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import 'room_repository.dart';

class ChatController extends ChangeNotifier {
  ChatController(this.repository, this.identity) {
    for (final message in repository.store.messages(identity.code)) {
      _messages[message.id] = message;
    }
    _listen();
  }
  static const pageSize = 30;
  final RoomRepository repository;
  final RoomIdentity identity;
  final Map<String, ChatMessage> _messages = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _members;
  DocumentSnapshot<Map<String, dynamic>>? _oldest;
  bool loadingHistory = false,
      hasMore = true,
      fromCache = true,
      disposed = false;
  bool _serverCursorReady = false;
  int memberCount = 1;
  String? error;
  Query<Map<String, dynamic>> get _query => repository
      .room(identity.code)
      .collection('messages')
      .orderBy('createdAt', descending: true);
  List<ChatMessage> get messages => _messages.values.toList()
    ..sort((a, b) {
      final time = b.sortTime.compareTo(a.sortTime);
      return time == 0 ? b.id.compareTo(a.id) : time;
    });
  void _listen() {
    _subscription = _query
        .limit(pageSize)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            fromCache = snapshot.metadata.isFromCache;
            for (final doc in snapshot.docs) {
              _messages[doc.id] = ChatMessage.fromDoc(doc);
            }
            if (!_serverCursorReady && snapshot.docs.isNotEmpty) {
              _oldest = snapshot.docs.last;
            }
            if (!fromCache && !_serverCursorReady) {
              _serverCursorReady = true;
              hasMore = snapshot.docs.length == pageSize;
            }
            _save();
            _notify();
          },
          onError: (Object e) {
            error =
                'Could not sync messages. Your saved history is still available.';
            _notify();
          },
        );
    _members = repository
        .room(identity.code)
        .collection('members')
        .snapshots()
        .listen(
          (snapshot) {
            memberCount = snapshot.docs.length;
            _notify();
          },
          onError: (Object e) {
            /* Cached membership is optional when offline. */
          },
        );
  }

  Future<void> loadMore() async {
    if (loadingHistory || !hasMore) return;
    loadingHistory = true;
    error = null;
    _notify();
    try {
      var query = _query.limit(pageSize);
      if (_oldest != null) query = query.startAfterDocument(_oldest!);
      final snapshot = await query.get().timeout(const Duration(seconds: 12));
      for (final doc in snapshot.docs) {
        _messages[doc.id] = ChatMessage.fromDoc(doc);
      }
      if (snapshot.docs.isNotEmpty) _oldest = snapshot.docs.last;
      // An empty cache page does not prove that server history is exhausted.
      if (!snapshot.metadata.isFromCache) {
        hasMore = snapshot.docs.length == pageSize;
      }
      if (snapshot.metadata.isFromCache && snapshot.docs.isEmpty) {
        error = 'Connect to load older messages.';
      }
      _save();
    } catch (_) {
      error = 'Older messages could not be loaded. Tap to retry.';
    } finally {
      loadingHistory = false;
      _notify();
    }
  }

  void send(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.length > 2000) return;
    final reference = repository
        .room(identity.code)
        .collection('messages')
        .doc();
    final now = DateTime.now();
    _messages[reference.id] = ChatMessage(
      id: reference.id,
      senderId: repository.uid,
      name: identity.name,
      text: text,
      clientTime: now,
      pending: true,
    );
    error = null;
    _notify();
    _save();
    // Firestore queues this write while offline and supplies the actual server time on acknowledgement.
    unawaited(
      reference
          .set({
            'senderId': repository.uid,
            'name': identity.name,
            'text': text,
            'clientTime': Timestamp.fromDate(now),
            'createdAt': FieldValue.serverTimestamp(),
          })
          .catchError((Object e) {
            _messages.remove(reference.id);
            error =
                'Message was not sent. Please copy your text and retry: $text';
            _save();
            _notify();
          }),
    );
  }

  void _save() {
    unawaited(repository.store.saveMessages(identity.code, messages));
  }

  void _notify() {
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    _subscription?.cancel();
    _members?.cancel();
    super.dispose();
  }
}
