part of '../api.dart';

/// Coaching's invitations (#553): a coach's one-person links, what a link says
/// to anyone who opens it, accepting, declining or blocking through one, and
/// the blocks an account holds.
mixin _InvitationRoutes on Requests {
  /// A one-person link from a coach, for someone they call [name], optionally
  /// with a library program the person gets on accepting. `201`, carrying the
  /// link's secret `token`, the one time besides a resend that it is readable.
  /// The [ServerRefusal] `403 coaching_beta` for an account that may not
  /// coach yet.
  Future<Invitation> createInvitation(String name, {String? programId}) async {
    final (json, _) = await post(Router.invitations, body: {'name': name, 'programId': ?programId});
    return Invitation.fromJson(json);
  }

  /// The coach's links, newest first, however they ended. Never a token.
  Future<({List<Invitation> items, String? cursor})> getInvitations({String? cursor}) async {
    final (invitations, page) = _listIn(
      await get(Router.invitations, query: _cursor(cursor)),
      'invitations',
      from: Router.invitations,
    );
    return (items: _readable(invitations, Invitation.fromJson), cursor: page['cursor'] as String?);
  }

  /// A new token and a new week for a link nobody has answered; the old token
  /// stops working.
  Future<Invitation> resendInvitation(String invitationId) async {
    final (json, _) = await post(Router.invitationResend(invitationId));
    return Invitation.fromJson(json);
  }

  /// Withdraws a link. Withdrawing one that's gone is not an error.
  Future<void> cancelInvitation(String invitationId) => delete(Router.invitation(invitationId));

  /// What a link says to anyone who opens it, signed in or not: whether it is
  /// still good and, while it is, the coach's name and photo. Null for a token
  /// the server never made.
  Future<InvitationPreview?> previewInvitation(String token) async {
    try {
      final (json, _) = await get(Router.invitationLink(token));
      return InvitationPreview.fromJson(json);
    } on Exception catch (error) {
      if (_gone(error)) return null;
      rethrow;
    }
  }

  /// Accepts a link, opening [shares] to the coach. One step: the connection,
  /// the shares, and "Your coach" on in the account's settings. Accepting again
  /// answers the same connection. The [ServerRefusal]s `400 invitation_gone`
  /// for a link that is no longer good, `400 own_invitation` for one's own.
  Future<AcceptedInvitation> acceptInvitation(String token, Set<ConnectionShare> shares) async {
    final (json, _) = await post(
      Router.invitationLinkAccept(token),
      body: {
        'shares': [for (final share in shares) share.name],
      },
    );
    return AcceptedInvitation.fromJson(json);
  }

  Future<void> declineInvitation(String token) => post(Router.invitationLinkDecline(token));

  /// Blocks whoever made the link, though no connection exists yet: their next
  /// link reads as one that is no longer good.
  Future<void> blockInviter(String token) => post(Router.invitationLinkBlock(token));

  /// Who the account has blocked, newest first.
  Future<({List<BlockedPerson> items, String? cursor})> getBlocks({String? cursor}) async {
    final (blocks, page) = _listIn(await get(Router.blocks, query: _cursor(cursor)), 'blocks', from: Router.blocks);
    return (items: _readable(blocks, BlockedPerson.fromJson), cursor: page['cursor'] as String?);
  }

  /// Lifts a block. It restores nothing: a connection it ended stays ended.
  Future<void> liftBlock(String userId) => delete(Router.block(userId));
}
