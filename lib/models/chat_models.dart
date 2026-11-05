import 'package:cloud_firestore/cloud_firestore.dart';

class RoomIdentity {
  const RoomIdentity({
    required this.code,
    required this.name,
    required this.seed,
  });
  final String code;
  final String name;
  final String seed;
  Map<String, dynamic> toJson() => {'code': code, 'name': name, 'seed': seed};
  factory RoomIdentity.fromJson(Map<String, dynamic> json) => RoomIdentity(
    code: json['code'] as String,
    name: json['name'] as String,
    seed: json['seed'] as String,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.name,
    required this.text,
    required this.clientTime,
    this.serverTime,
    this.pending = false,
  });
  final String id, senderId, name, text;
  final DateTime clientTime;
  final DateTime? serverTime;
  final bool pending;
  DateTime get sortTime => serverTime ?? clientTime;
  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String,
      name: data['name'] as String,
      text: data['text'] as String,
      clientTime: (data['clientTime'] as Timestamp).toDate(),
      serverTime: (data['createdAt'] as Timestamp?)?.toDate(),
      pending: doc.metadata.hasPendingWrites,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'name': name,
    'text': text,
    'clientTime': clientTime.toIso8601String(),
    'serverTime': serverTime?.toIso8601String(),
    'pending': pending,
  };
  factory ChatMessage.fromJson(Map<String, dynamic> data) => ChatMessage(
    id: data['id'] as String,
    senderId: data['senderId'] as String,
    name: data['name'] as String,
    text: data['text'] as String,
    clientTime: DateTime.parse(data['clientTime'] as String),
    serverTime: data['serverTime'] == null
        ? null
        : DateTime.parse(data['serverTime'] as String),
    pending: data['pending'] as bool? ?? false,
  );
}

String pseudonymFromSeed(String seed) {
  const adjectives = [
    'Brave',
    'Cosmic',
    'Quiet',
    'Golden',
    'Curious',
    'Misty',
    'Velvet',
    'Happy',
    'Silver',
    'Lucky',
    'Gentle',
    'Clever',
    'Sunny',
    'Wild',
    'Little',
    'Swift',
  ];
  const animals = [
    'Badger',
    'Otter',
    'Panda',
    'Fox',
    'Owl',
    'Koala',
    'Lynx',
    'Panther',
    'Robin',
    'Tiger',
    'Dolphin',
    'Falcon',
    'Rabbit',
    'Gecko',
    'Wolf',
    'Finch',
  ];
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = ((hash * 31) + unit) & 0x7fffffff;
  }
  return '${adjectives[hash % adjectives.length]} ${animals[(hash ~/ adjectives.length) % animals.length]}';
}

bool validRoomCode(String code) => RegExp(r'^\d{6}$').hasMatch(code);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
