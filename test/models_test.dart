import 'package:flutter_test/flutter_test.dart';
import 'package:rumor_app/data/local_store.dart';
import 'package:rumor_app/models/chat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('room codes must contain exactly six digits', () {
    expect(validRoomCode('123456'), isTrue);
    for (final code in ['', '12345', '1234567', 'abcdef', '../123']) {
      expect(validRoomCode(code), isFalse);
    }
  });
  test('API seed deterministically generates a two-word pseudonym', () {
    expect(pseudonymFromSeed('sample-uuid'), pseudonymFromSeed('sample-uuid'));
    expect(pseudonymFromSeed('sample-uuid').split(' ').length, 2);
  });
  test(
    'rejoining a room keeps its identity while other rooms stay distinct',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalStore(await SharedPreferences.getInstance());
      const a = RoomIdentity(code: '123456', name: 'Brave Badger', seed: 'a');
      const b = RoomIdentity(code: '654321', name: 'Quiet Otter', seed: 'b');
      await store.saveIdentity(a);
      await store.saveIdentity(b);
      await store.saveIdentity(a);
      final reopened = LocalStore(await SharedPreferences.getInstance());
      expect(reopened.rooms.length, 2);
      expect(reopened.identity('123456')!.seed, 'a');
      expect(reopened.identity('654321')!.name, 'Quiet Otter');
      expect(reopened.rooms.first.code, '123456');
    },
  );
  test(
    'loaded messages survive a new local store, including pending writes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalStore(await SharedPreferences.getInstance());
      final date = DateTime(2026, 11, 5, 12);
      await store.saveMessages('123456', [
        ChatMessage(
          id: 'm1',
          senderId: 'a',
          name: 'Brave Badger',
          text: 'Saved offline',
          clientTime: date,
          serverTime: date,
        ),
        ChatMessage(
          id: 'm2',
          senderId: 'a',
          name: 'Brave Badger',
          text: 'Queued offline',
          clientTime: date,
          pending: true,
        ),
      ]);
      final reopened = LocalStore(await SharedPreferences.getInstance());
      expect(reopened.messages('123456').first.serverTime, date);
      expect(reopened.messages('123456').last.pending, isTrue);
      expect(reopened.messages('654321'), isEmpty);
    },
  );
  test('date separators respect year and month boundaries', () {
    expect(sameDay(DateTime(2026, 11, 5), DateTime(2026, 11, 5, 23)), isTrue);
    expect(sameDay(DateTime(2026, 11, 5), DateTime(2026, 10, 5)), isFalse);
    expect(sameDay(DateTime(2026, 11, 5), DateTime(2025, 11, 5)), isFalse);
  });
}
