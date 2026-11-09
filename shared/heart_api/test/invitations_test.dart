import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'support/http.dart';

void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  group('invitations (#553)', () {
    // what the server answered in heart-api's own run of these routes
    final created = <String, dynamic>{
      'id': '01a1b7d4-bcb8-77f5-b026-b04a7f1a6354',
      'name': 'Riley',
      'status': 'pending',
      'role': 'COACH',
      'domain': 'fitness',
      'expiresAt': '2026-11-14T21:05:34.901276Z',
      'createdAt': '2026-11-07T21:05:34.902903Z',
      'token': 'xXDXGFUIr2-PRY0Nj5f1HLMDdggBB4rFUU-6d4lFLmk',
    };
    const token = '9kAxjMgFcH8wAlbJUwiesRT-ZcvQ2_KOJe4mC645glM';

    Object? sentBody(String method, String path) {
      final uri = Uri.https('api.example.com', path);
      final captured = switch (method) {
        'POST' => verify(client.post(uri, headers: anyNamed('headers'), body: captureAnyNamed('body'))).captured,
        _ => verify(client.put(uri, headers: anyNamed('headers'), body: captureAnyNamed('body'))).captured,
      };
      return jsonDecode(captured.single as String);
    }

    test('createInvitation sends the name, and leaves out a program not chosen', () async {
      respond(client: client, method: 'POST', path: Router.invitations, statusCode: 201, body: created);

      final invitation = await api.createInvitation('Riley');

      expect(invitation.token, created['token']);
      expect(invitation.status, 'pending');
      expect(sentBody('POST', Router.invitations), {'name': 'Riley'});
    });

    test('createInvitation throws the beta refusal whole', () async {
      respond(
        client: client,
        method: 'POST',
        path: Router.invitations,
        statusCode: 403,
        body: {
          'error': 'forbidden',
          'code': 'coaching_beta',
          'reason': 'coaching is open to testers for now',
        },
      );
      expect(api.createInvitation('Riley'), throwsA(containsPair('code', 'coaching_beta')));
    });

    test('getInvitations reads the page and its cursor, and never a token', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.invitations,
        statusCode: 200,
        body: {
          'invitations': [
            {...created}..remove('token'),
          ],
          'cursor': 'next',
        },
      );

      final (:items, :cursor) = await api.getInvitations();

      expect(items.single.name, 'Riley');
      expect(items.single.token, isNull);
      expect(cursor, 'next');
    });

    test('previewInvitation: good, gone, and a token the server never made', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.invitationLink(token),
        statusCode: 200,
        body: {
          'inviterName': 'dana_551191',
          'good': true,
        },
      );
      respond(
        client: client,
        method: 'GET',
        path: Router.invitationLink('gone'),
        statusCode: 200,
        body: {
          'good': false,
        },
      );
      respond(
        client: client,
        method: 'GET',
        path: Router.invitationLink('nope'),
        statusCode: 404,
        body: {
          'error': 'not found',
          'code': 'not_found',
        },
      );

      final good = await api.previewInvitation(token);
      expect((good?.good, good?.inviterName), (true, 'dana_551191'));
      expect((await api.previewInvitation('gone'))?.good, isFalse);
      expect(await api.previewInvitation('nope'), isNull);
    });

    test('acceptInvitation sends the shares and reads the connection and the program', () async {
      respond(
        client: client,
        method: 'POST',
        path: Router.invitationLinkAccept(token),
        statusCode: 200,
        body: {
          'targetId': 'CoachDanaUid551191',
          'role': 'student',
          'domain': 'fitness',
          'status': 'active',
          'createdAt': '2026-11-07T21:05:34.981347Z',
          'connectionId': '01a1b7d4-bd0d-7eec-a569-2bc08ea3787f',
          'acceptedAt': '2026-11-07T21:05:34.981347Z',
          'shares': ['history'],
          'programDelivered': true,
          'programId': '01a1b7d4-bd28-7e4b-9307-80fbe12ecd6c',
        },
      );

      final accepted = await api.acceptInvitation(token, {.history});

      expect(accepted.connection.role, ConnectionRole.student);
      expect(accepted.delivery?.delivered, isTrue);
      expect(accepted.delivery?.programId, '01a1b7d4-bd28-7e4b-9307-80fbe12ecd6c');
      expect(sentBody('POST', Router.invitationLinkAccept(token)), {
        'shares': ['history'],
      });
    });

    test('acceptInvitation throws a link that is no longer good whole', () async {
      respond(
        client: client,
        method: 'POST',
        path: Router.invitationLinkAccept(token),
        statusCode: 400,
        body: {
          'error': 'bad request',
          'code': 'invitation_gone',
          'reason': 'this invitation is no longer good',
        },
      );
      expect(api.acceptInvitation(token, {}), throwsA(containsPair('code', 'invitation_gone')));
    });

    test('a token that is not one the server makes never reaches a path', () {
      for (final crafted in ['../../v1/accounts/x', 'a/b', 'a b', '', 'a%2F..']) {
        expect(() => Router.invitationLink(crafted), throwsArgumentError, reason: crafted);
        expect(() => api.previewInvitation(crafted), throwsArgumentError, reason: crafted);
      }
      verifyNever(client.get(any, headers: anyNamed('headers')));
    });

    test('declining, blocking, listing and lifting blocks', () async {
      respond(client: client, method: 'POST', path: Router.invitationLinkDecline(token), statusCode: 204, body: {});
      respond(client: client, method: 'POST', path: Router.invitationLinkBlock(token), statusCode: 204, body: {});
      respond(
        client: client,
        method: 'GET',
        path: Router.blocks,
        statusCode: 200,
        body: {
          'blocks': [
            {'id': 'CoachDanaUid551191', 'name': 'dana_551191', 'since': '2026-11-07T21:05:35.103299Z'},
          ],
        },
      );
      respond(client: client, method: 'DELETE', path: Router.block('CoachDanaUid551191'), statusCode: 204, body: {});

      await api.declineInvitation(token);
      await api.blockInviter(token);
      final (:items, :cursor) = await api.getBlocks();
      expect(items.single.name, 'dana_551191');
      expect(cursor, isNull);
      await api.liftBlock('CoachDanaUid551191');
    });

    test('resending and cancelling', () async {
      const id = '01a1b7d4-bcc0-7f48-8e45-06dced4cadcb';
      respond(
        client: client,
        method: 'POST',
        path: Router.invitationResend(id),
        statusCode: 200,
        body: {
          ...created,
          'id': id,
          'token': 'fresh',
        },
      );
      respond(client: client, method: 'DELETE', path: Router.invitation(id), statusCode: 204, body: {});

      expect((await api.resendInvitation(id)).token, 'fresh');
      await api.cancelInvitation(id);
    });
  });
}
