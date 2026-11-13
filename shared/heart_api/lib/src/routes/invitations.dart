part of '../api.dart';

/// Coaching's invitations (#553): a coach's one-person links, what a link says
/// to anyone who opens it, accepting, declining or blocking through one, and
/// the blocks an account holds.
mixin _InvitationRoutes on Requests {
  /// A one-person link from a coach, for someone they call [name], optionally
  /// with a library program the person gets on accepting. `201`, carrying the
  /// link's secret `token`, the one time besides a resend that it is readable.
  /// `403 coaching_beta` for an account that may not coach yet, thrown whole.
  Future<Invitation> createInvitation(String name, {String? programId}) async {
    final (json, code) = await post(Router.invitations, body: {'name': name, 'programId': ?programId});
    return switch ((code, json)) {
      (201, Map json) => Invitation.fromJson(json),
      _ => throw json,
    };
  }

  /// The coach's links, newest first, however they ended. Never a token.
  Future<({List<Invitation> items, String? cursor})> getInvitations({String? cursor}) async {
    final (json, code) = await get(Router.invitations, query: _cursor(cursor));
    return switch ((code, json)) {
      (200, {'invitations': List l}) => (items: _readable(l, Invitation.fromJson), cursor: json['cursor'] as String?),
      _ => throw json,
    };
  }

  /// A new token and a new week for a link nobody has answered; the old token
  /// stops working.
  Future<Invitation> resendInvitation(String invitationId) async {
    final (json, code) = await post(Router.invitationResend(invitationId));
    return switch ((code, json)) {
      (200, Map json) => Invitation.fromJson(json),
      _ => throw json,
    };
  }

  /// Withdraws a link. Withdrawing one that's gone is not an error.
  Future<void> cancelInvitation(String invitationId) async {
    final (json, code) = await delete(Router.invitation(invitationId));
    if (code != 204) throw json;
  }

  /// What a link says to anyone who opens it, signed in or not: whether it is
  /// still good and, while it is, the coach's name and photo. Null for a token
  /// the server never made.
  Future<InvitationPreview?> previewInvitation(String token) async {
    final (json, code) = await get(Router.invitationLink(token));
    return switch ((code, json)) {
      (200, Map json) => InvitationPreview.fromJson(json),
      (404, _) => null,
      _ => throw json,
    };
  }

  /// Accepts a link, opening [shares] to the coach. One step: the connection,
  /// the shares, and "Your coach" on in the account's settings. Accepting again
  /// answers the same connection. `400 invitation_gone` for a link that is no
  /// longer good, `400 own_invitation` for one's own, thrown whole.
  Future<AcceptedInvitation> acceptInvitation(String token, Set<ConnectionShare> shares) async {
    final (json, code) = await post(
      Router.invitationLinkAccept(token),
      body: {
        'shares': [for (final share in shares) share.name],
      },
    );
    return switch ((code, json)) {
      (200, Map json) => AcceptedInvitation.fromJson(json),
      _ => throw json,
    };
  }

  Future<void> declineInvitation(String token) async {
    final (json, code) = await post(Router.invitationLinkDecline(token));
    if (code != 204) throw json;
  }

  /// Blocks whoever made the link, though no connection exists yet: their next
  /// link reads as one that is no longer good.
  Future<void> blockInviter(String token) async {
    final (json, code) = await post(Router.invitationLinkBlock(token));
    if (code != 204) throw json;
  }

  /// Who the account has blocked, newest first.
  Future<({List<BlockedPerson> items, String? cursor})> getBlocks({String? cursor}) async {
    final (json, code) = await get(Router.blocks, query: _cursor(cursor));
    return switch ((code, json)) {
      (200, {'blocks': List l}) => (items: _readable(l, BlockedPerson.fromJson), cursor: json['cursor'] as String?),
      _ => throw json,
    };
  }

  /// Lifts a block. It restores nothing: a connection it ended stays ended.
  Future<void> liftBlock(String userId) async {
    final (json, code) = await delete(Router.block(userId));
    if (code != 204) throw json;
  }
}
