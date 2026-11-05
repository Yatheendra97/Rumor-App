import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rumor_app/main.dart' as app;
import 'package:rumor_app/ui/room_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const captureDemo = bool.fromEnvironment('CAPTURE_DEMO');
  const recordDemo = bool.fromEnvironment('RECORD_DEMO');
  testWidgets(
    'real Firebase: create, join, live reply, pagination, offline rejoin, queued send',
    (tester) async {
      Future<void> until(bool Function() condition, {int seconds = 40}) async {
        final end = DateTime.now().add(Duration(seconds: seconds));
        while (!condition() && DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(
          condition(),
          isTrue,
          reason: 'Timed out waiting for workflow condition',
        );
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> tap(Key key) async {
        await tester.pump(const Duration(milliseconds: 200));
        final finder = find.byKey(key);
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump(const Duration(milliseconds: 600));
      }

      Future<void> capture(String name) async {
        if (captureDemo || recordDemo) {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 2));
          if (captureDemo) await binding.takeScreenshot(name);
        }
      }

      await app.main();
      await tester.pumpAndSettle();
      debugPrint('WORKFLOW_RECORD_START');
      if (captureDemo) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
      }
      await capture('01-join-room');
      await tap(const Key('createRoom'));
      await until(
        () => find.byKey(const Key('identityName')).evaluate().isNotEmpty,
      );
      final identity = tester
          .widget<RoomScreen>(find.byType(RoomScreen))
          .identity;
      final code = identity.code;
      final firstName = identity.name;
      debugPrint('WORKFLOW room=$code identity=$firstName');
      await capture('02-room-identity');
      await tap(const Key('acknowledge'));
      await tester.enterText(
        find.byKey(const Key('composer')),
        'Hello from the first anonymous guest!',
      );
      await tap(const Key('send'));
      await until(() => find.text('Sending…').evaluate().isEmpty);

      // A completely separate Firebase app simulates another device, with its own auth/cache.
      final secondApp = await Firebase.initializeApp(
        name: 'second-device',
        options: Firebase.app().options,
      );
      final secondAuth = FirebaseAuth.instanceFor(app: secondApp);
      final secondDb = FirebaseFirestore.instanceFor(app: secondApp);
      await secondAuth.signInAnonymously();
      final secondUid = secondAuth.currentUser!.uid;
      final room = secondDb.collection('rooms').doc(code);
      await room.get();
      // Users without membership may find a known room, but cannot read its messages.
      await expectLater(
        room.collection('messages').get(),
        throwsA(isA<FirebaseException>()),
      );
      await room.collection('members').doc(secondUid).set({
        'name': 'Brave Badger',
        'seed': 'workflow-second-device',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      Future<void> reply(String text) => room.collection('messages').add({
        'senderId': secondUid,
        'name': 'Brave Badger',
        'text': text,
        'clientTime': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await reply('Hi! The same room, a different identity.');
      await until(
        () => find
            .text('Hi! The same room, a different identity.')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text('@BraveBadger'), findsOneWidget);
      await capture('03-realtime-chat');
      await until(() => find.text('2 members').evaluate().isNotEmpty);
      final doc = await room.collection('messages').limit(1).get();
      await expectLater(
        doc.docs.first.reference.update({'text': 'tampered'}),
        throwsA(isA<FirebaseException>()),
      );
      await expectLater(
        room.collection('messages').add({
          'senderId': secondUid,
          'name': 'Spoofed identity',
          'text': 'spoof attempt',
          'clientTime': Timestamp.now(),
          'createdAt': FieldValue.serverTimestamp(),
        }),
        throwsA(isA<FirebaseException>()),
      );

      await tap(const Key('leaveRoom'));
      for (var i = 1; i <= 35; i++) {
        await reply('History message ${i.toString().padLeft(2, '0')}');
      }
      await tap(Key('recent_$code'));
      await until(
        () => find.byKey(const Key('identityName')).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('identityName'))).data,
        firstName.replaceFirst(' ', '\n'),
      );
      await tap(const Key('acknowledge'));
      await tester.pump(const Duration(seconds: 3));
      final session = tester.state(find.byType(RoomScreen)) as dynamic;
      debugPrint(
        'PAGINATION before count=${session.chat.messages.length} more=${session.chat.hasMore}',
      );
      final listState = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('messages')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      listState.position.jumpTo(listState.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tap(const Key('loadOlder'));
      await tester.pump(const Duration(seconds: 3));
      debugPrint(
        'PAGINATION after count=${session.chat.messages.length} error=${session.chat.error} texts=${session.chat.messages.map((m) => m.text).toList()}',
      );
      expect(session.chat.messages.length, 37);
      listState.position.jumpTo(listState.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.text('Hello from the first anonymous guest!'),
        findsOneWidget,
      );
      await tap(const Key('leaveRoom'));
      await FirebaseFirestore.instance.disableNetwork();
      // Recreate the entire widget tree and LocalStore to verify durable offline re-entry.
      await tester.pumpWidget(const SizedBox.shrink());
      await app.main();
      await tester.pumpAndSettle();
      await tap(Key('recent_$code'));
      await until(
        () => find.byKey(const Key('identityName')).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('identityName'))).data,
        firstName.replaceFirst(' ', '\n'),
      );
      await tap(const Key('acknowledge'));
      await tester.enterText(
        find.byKey(const Key('composer')),
        'Queued offline, delivered after reconnect.',
      );
      await tap(const Key('send'));
      expect(
        find.text('Queued offline, delivered after reconnect.'),
        findsOneWidget,
      );
      expect(find.text('Sending…'), findsOneWidget);
      final offlineSession = tester.state(find.byType(RoomScreen)) as dynamic;
      expect(offlineSession.chat.messages.length, 38);
      await capture('05-offline-queued-message');
      await FirebaseFirestore.instance.enableNetwork();
      await until(() => find.text('Sending…').evaluate().isEmpty);
      final queued = await room
          .collection('messages')
          .where(
            'text',
            isEqualTo: 'Queued offline, delivered after reconnect.',
          )
          .get();
      expect(queued.docs.length, 1);
      expect(queued.docs.first.data()['createdAt'], isA<Timestamp>());
      await capture('06-reconnected-message');
      await tap(const Key('leaveRoom'));
      // Join a different room through the code-entry UI, generating a fresh API identity.
      final otherCode =
          (100000 + DateTime.now().microsecondsSinceEpoch % 900000).toString();
      final otherRoom = secondDb.collection('rooms').doc(otherCode);
      final batch = secondDb.batch();
      batch.set(otherRoom, {
        'createdBy': secondUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(otherRoom.collection('members').doc(secondUid), {
        'name': 'Brave Badger',
        'seed': 'second-room-host',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      await tester.enterText(find.byKey(const Key('roomCode')), otherCode);
      await tap(const Key('joinRoom'));
      await until(
        () => find.byKey(const Key('identityName')).evaluate().isNotEmpty,
      );
      final otherIdentity = tester
          .widget<RoomScreen>(find.byType(RoomScreen))
          .identity;
      expect(otherIdentity.code, otherCode);
      expect(otherIdentity.seed, isNot(identity.seed));
      await capture('07-join-existing-room');
      await tap(const Key('acknowledge'));
      await tester.enterText(
        find.byKey(const Key('composer')),
        'New room. New anonymous identity.',
      );
      await tap(const Key('send'));
      await until(() => find.text('Sending…').evaluate().isEmpty);
      await tap(const Key('roomMenu'));
      await tester.tap(find.text('Toggle theme'));
      await tester.pumpAndSettle();
      await capture('08-light-mode');
      await tap(const Key('roomMenu'));
      await tester.tap(find.text('Toggle theme'));
      await tester.pumpAndSettle();
      await tap(const Key('leaveRoom'));
      await tap(Key('recent_$code'));
      await until(
        () => find.byKey(const Key('identityName')).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('identityName'))).data,
        firstName.replaceFirst(' ', '\n'),
      );
      await tap(const Key('acknowledge'));
      await capture('09-return-to-original-room');
      await secondAuth.signOut();
      await secondDb.terminate();
      await secondApp.delete();
      debugPrint(
        'WORKFLOW PASS: identity reuse, realtime two-client chat, 30+ message pagination, offline rejoin, queued delivery, membership and immutability rules.',
      );
    },
  );
}
