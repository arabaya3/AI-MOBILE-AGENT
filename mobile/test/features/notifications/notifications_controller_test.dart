import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/providers.dart';
import 'package:teia_ai/features/auth/application/auth_controller.dart';
import 'package:teia_ai/features/notifications/application/notifications_controller.dart';

import '../../support/container.dart';
import '../../support/fake_adapter.dart';
import '../../support/fake_backend.dart';

class TestScope extends Notifier<String?> {
  @override
  String? build() => 'u1#1';

  void set(String? value) => state = value;
}

final testAuthScope = NotifierProvider<TestScope, String?>(TestScope.new);

Map<String, dynamic> note(
  String id, {
  bool read = false,
  String type = 'policy_updated',
}) => {
  'id': id,
  'user_id': 'u1',
  'space_id': 's1',
  'type': type,
  'title': 'Policy Updated',
  'message': 'The access policy for Team has been updated.',
  'metadata': {'space_name': 'Team'},
  'read': read,
  'created_at': '2026-11-02T08:00:00',
};

Uint8List frame(String event, Object data) => Uint8List.fromList(
  utf8.encode('event: $event\ndata: ${jsonEncode(data)}\n\n'),
);

/// A backend whose notification stream is controlled by the test, one controller per connection.
class LiveBackend {
  LiveBackend({List<Map<String, dynamic>>? initial}) {
    list = initial ?? [];
    backend
      ..on('GET /notifications/', (_) => jsonBody(200, list))
      ..on(
        'GET /notifications/unread-count',
        (_) => jsonBody(200, {
          'count': list.where((n) => n['read'] != true).length,
        }),
      )
      ..on('GET /notifications/stream', (_) {
        final controller = StreamController<Uint8List>();
        connections.add(controller);
        return streamBody(200, controller.stream);
      })
      ..on(
        'POST /notifications/n1/read',
        (_) => jsonBody(200, {'success': true}),
      )
      ..on(
        'POST /notifications/mark-all-read',
        (_) => jsonBody(200, {'count': 2}),
      );
  }

  final backend = FakeBackend();
  final connections = <StreamController<Uint8List>>[];
  late List<Map<String, dynamic>> list;

  StreamController<Uint8List> get live => connections.last;

  int get streamRequests =>
      backend.requestsTo('GET /notifications/stream').length;
  int get listRequests => backend.requestsTo('GET /notifications/').length;
}

Future<ProviderContainer> notificationsContainer(LiveBackend live) async {
  final c = await makeContainer(
    live.backend,
    liveNotifications: true,
    overrides: [
      authScopeProvider.overrideWith((ref) => ref.watch(testAuthScope)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

NotificationsState stateOf(ProviderContainer c) =>
    c.read(notificationsControllerProvider);

void main() {
  test(
    'live events are added once and never inflate the unread count',
    () async {
      final live = LiveBackend(initial: [note('n1')]);
      final c = await notificationsContainer(live);
      fakeAsync((async) {
        c.listen(notificationsControllerProvider, (_, _) {});
        async.elapse(const Duration(milliseconds: 10));
        live.live.add(frame('connected', {'user_id': 'u1'}));
        async.elapse(const Duration(milliseconds: 10));
        expect(stateOf(c).live, LiveStatus.live);
        expect(stateOf(c).unread, 1);

        live.live.add(frame('notification', note('n2')));
        live.live.add(frame('notification', note('n2')));
        live.live.add(frame('notification', note('n1')));
        async.elapse(const Duration(milliseconds: 10));
        expect(stateOf(c).items!.map((n) => n.id), ['n2', 'n1']);
        expect(stateOf(c).unread, 2);
        c.read(appForegroundProvider.notifier).set(false);
        async.elapse(const Duration(milliseconds: 10));
      });
    },
  );

  // Real time with short delays: a closed Dio stream does not complete under fakeAsync.
  test(
    'reconnects with bounded backoff and reloads the list after reconnecting',
    () async {
      final live = LiveBackend(initial: [note('n1')]);
      final c = await makeContainer(
        live.backend,
        liveNotifications: true,
        overrides: [
          authScopeProvider.overrideWith((ref) => ref.watch(testAuthScope)),
          notificationsBackoffProvider.overrideWithValue(const [
            Duration(milliseconds: 100),
            Duration(milliseconds: 400),
          ]),
        ],
      );
      addTearDown(c.dispose);
      Future<void> wait(int ms) =>
          Future<void>.delayed(Duration(milliseconds: ms));
      c.listen(notificationsControllerProvider, (_, _) {});
      await wait(30);
      live.live.add(frame('connected', {}));
      await wait(30);
      final listsBefore = live.listRequests;

      // The link drops; something arrives while offline.
      live.list = [note('n9'), note('n1')];
      await live.live.close();
      await wait(30);
      expect(stateOf(c).live, LiveStatus.waiting);
      expect(live.streamRequests, 1);
      await wait(120);
      expect(live.streamRequests, 2);

      await live.live.close();
      await wait(200);
      expect(live.streamRequests, 2, reason: 'the second delay is longer');
      await wait(300);
      expect(live.streamRequests, 3);
      await live.live.close();
      await wait(450);
      expect(live.streamRequests, 4, reason: 'the last delay repeats');

      live.live.add(frame('connected', {}));
      await wait(50);
      expect(live.listRequests, greaterThan(listsBefore));
      expect(stateOf(c).items!.map((n) => n.id), ['n9', 'n1']);
      expect(stateOf(c).unread, 2);
      c.read(appForegroundProvider.notifier).set(false);
      await wait(10);
    },
  );

  test(
    'backgrounding closes the link without retrying; returning reconnects',
    () async {
      final live = LiveBackend();
      final c = await notificationsContainer(live);
      fakeAsync((async) {
        c.listen(notificationsControllerProvider, (_, _) {});
        async.elapse(const Duration(milliseconds: 10));
        c.read(appForegroundProvider.notifier).set(false);
        async.elapse(const Duration(minutes: 5));
        expect(live.streamRequests, 1);
        expect(live.backend.adapter.cancelledRequests, greaterThanOrEqualTo(1));
        expect(stateOf(c).live, LiveStatus.off);

        c.read(appForegroundProvider.notifier).set(true);
        async.elapse(const Duration(milliseconds: 10));
        expect(live.streamRequests, 2);
        c.read(appForegroundProvider.notifier).set(false);
        async.elapse(const Duration(milliseconds: 10));
      });
    },
  );

  test(
    'an account change drops the previous account and ignores its late events',
    () async {
      final live = LiveBackend(initial: [note('n1')]);
      final c = await notificationsContainer(live);
      fakeAsync((async) {
        c.listen(notificationsControllerProvider, (_, _) {});
        async.elapse(const Duration(milliseconds: 10));
        // Closed by the controller when the account changes.
        // ignore: close_sinks
        final oldLink = live.live;
        expect(stateOf(c).items, isNotEmpty);

        live.list = [];
        c.read(testAuthScope.notifier).set('u2#2');
        async.elapse(const Duration(milliseconds: 10));
        oldLink.add(frame('notification', note('late')));
        async.elapse(const Duration(milliseconds: 10));
        expect(stateOf(c).items, isEmpty);
        expect(stateOf(c).unread, 0);

        c.read(testAuthScope.notifier).set(null);
        async.elapse(const Duration(minutes: 1));
        expect(stateOf(c).items, isEmpty);
      });
    },
  );

  test('marking read updates the count once', () async {
    final live = LiveBackend(initial: [note('n1'), note('n2', read: true)]);
    final c = await notificationsContainer(live);
    c.read(notificationsControllerProvider);
    await settle();
    expect(stateOf(c).unread, 1);
    await c.read(notificationsControllerProvider.notifier).markRead('n1');
    await c.read(notificationsControllerProvider.notifier).markRead('n1');
    expect(stateOf(c).unread, 0);
    expect(
      live.backend.requestsTo('POST /notifications/n1/read'),
      hasLength(1),
    );
    c.read(appForegroundProvider.notifier).set(false);
    await settle();
  });
}
