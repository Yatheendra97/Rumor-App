import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';

class LocalStore {
  LocalStore(this.prefs);
  final SharedPreferences prefs;
  List<RoomIdentity> get rooms {
    final raw = prefs.getStringList('rooms') ?? [];
    return raw
        .map(
          (s) => RoomIdentity.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList();
  }

  RoomIdentity? identity(String code) {
    for (final room in rooms) {
      if (room.code == code) return room;
    }
    return null;
  }

  Future<void> saveIdentity(RoomIdentity identity) async {
    final list = [identity, ...rooms.where((r) => r.code != identity.code)];
    await prefs.setStringList(
      'rooms',
      list.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  List<ChatMessage> messages(String code) {
    final raw = prefs.getString('messages_$code');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveMessages(String code, Iterable<ChatMessage> messages) async {
    await prefs.setString(
      'messages_$code',
      jsonEncode(messages.map((m) => m.toJson()).toList()),
    );
  }

  bool get lightMode => prefs.getBool('lightMode') ?? false;
  Future<void> setLightMode(bool value) => prefs.setBool('lightMode', value);
}
