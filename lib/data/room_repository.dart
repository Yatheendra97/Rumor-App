import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import 'local_store.dart';

class RoomException implements Exception {
  RoomException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RoomRepository {
  RoomRepository(this.store, {FirebaseFirestore? db, FirebaseAuth? auth})
    : db = db ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;
  final LocalStore store;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  String get uid => auth.currentUser?.uid ?? '';
  DocumentReference<Map<String, dynamic>> room(String code) =>
      db.collection('rooms').doc(code);
  Future<void> authenticate() async {
    if (auth.currentUser != null) return;
    try {
      await auth.signInAnonymously().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw RoomException('Connect to the internet to enter your first room.');
    }
  }

  Future<RoomIdentity> join(String code) async {
    if (!validRoomCode(code)) throw RoomException('Enter a 6-digit room code.');
    final saved = store.identity(code);
    if (saved != null && auth.currentUser != null) {
      await store.saveIdentity(saved);
      return saved;
    }
    await authenticate();
    DocumentSnapshot<Map<String, dynamic>> document;
    try {
      document = await room(code)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw RoomException(
        'You are offline. Reopen a recent room or try again when connected.',
      );
    }
    if (!document.exists) {
      throw RoomException(
        'That room does not exist. Check the code or create a new room.',
      );
    }
    return _register(code);
  }

  Future<RoomIdentity> create() async {
    await authenticate();
    // Generate the identity first so an unavailable API cannot leave an orphan room.
    final seed = await _randomSeed();
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = (100000 + Random.secure().nextInt(900000)).toString();
      try {
        await db
            .runTransaction((transaction) async {
              final document = await transaction.get(room(code));
              if (document.exists) throw RoomException('collision');
              transaction.set(room(code), {
                'createdAt': FieldValue.serverTimestamp(),
                'createdBy': uid,
              });
              transaction.set(room(code).collection('members').doc(uid), {
                'name': pseudonymFromSeed(seed),
                'seed': seed,
                'joinedAt': FieldValue.serverTimestamp(),
              });
            })
            .timeout(const Duration(seconds: 18));
        final identity = RoomIdentity(
          code: code,
          name: pseudonymFromSeed(seed),
          seed: seed,
        );
        await store.saveIdentity(identity);
        return identity;
      } on RoomException catch (error) {
        if (error.message != 'collision') rethrow;
      } on TimeoutException {
        throw RoomException(
          'Creating a room needs an internet connection. Please try again.',
        );
      }
    }
    throw RoomException('Could not reserve a room code. Please try again.');
  }

  Future<String> _randomSeed() async {
    try {
      final response = await http
          .get(Uri.parse('https://randomuser.me/api/'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw RoomException(
          'Identity service is unavailable. Please try again.',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ((json['results'] as List).first['login']['uuid']) as String;
    } on TimeoutException {
      throw RoomException(
        'Identity generation timed out. Check your connection and retry.',
      );
    } on http.ClientException {
      throw RoomException(
        'Could not reach the identity service. Please retry when connected.',
      );
    }
  }

  Future<RoomIdentity> _register(String code) async {
    final existing = await room(
      code,
    ).collection('members').doc(uid).get().timeout(const Duration(seconds: 12));
    if (existing.exists) {
      final data = existing.data()!;
      final identity = RoomIdentity(
        code: code,
        name: data['name'] as String,
        seed: data['seed'] as String,
      );
      await store.saveIdentity(identity);
      return identity;
    }
    final seed = await _randomSeed();
    final identity = RoomIdentity(
      code: code,
      name: pseudonymFromSeed(seed),
      seed: seed,
    );
    await room(code)
        .collection('members')
        .doc(uid)
        .set({
          'name': identity.name,
          'seed': seed,
          'joinedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 15));
    await store.saveIdentity(identity);
    return identity;
  }
}
