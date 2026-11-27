import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/remote.dart';
import 'package:heart_state/src/templates.dart';

import 'test_utils.dart';

/// Templates made or replaced elsewhere, by an assistant or another device,
/// read again without a relaunch, and what happens to a change this device
/// still owed the server when they are (#448).
///
/// Hand-made fakes, not the file-wide mocks: the mirror has to remember what
/// it was given for the base of a change to mean anything.
void main() {
  const uid = 'u1';

  late _Mirror mirror;
  late _Server server;
  late _Folders folders;
  late _Unsent unsent;
  late List<Object> errors;

  Templates build({RemoteAccess? remote, bool keepsUnsent = true}) {
    return Templates(
      service: mirror,
      remoteService: server,
      configService: _NoSamples(),
      folderService: _LocalFolders(folders),
      remoteFolderService: _RemoteFolders(folders),
      filingService: server,
      unsent: keepsUnsent ? unsent : null,
      remote: remote,
      onError: (error, {stacktrace}) => errors.add(error as Object),
    )..keptName = (name) => 'Your changes: $name';
  }

  /// A signed-in launch whose server holds [onServer].
  Future<Templates> launched(List<Template> onServer, {bool keepsUnsent = true}) async {
    server.rows
      ..clear()
      ..addAll({for (final each in onServer) each.id: each});
    final templates = build(keepsUnsent: keepsUnsent)..userId = uid;
    await templates.init();
    return templates;
  }

  /// The user changes [id]'s name to [name] in the editor and saves.
  Future<void> rename(Templates templates, String id, String name) async {
    templates.editable = templates.lookup(id)!..name = name;
    await templates.saveEditable();
  }

  setUp(() {
    mirror = _Mirror();
    server = _Server();
    folders = _Folders();
    unsent = _Unsent(mirror);
    errors = [];
  });

  group('refresh', () {
    test('a template made elsewhere shows without a relaunch, and reaches the mirror', () async {
      final templates = await launched([_template('t1', 'Push')]);
      final probe = ListenerProbe()..attach(templates);
      server.rows['t2'] = _template('t2', 'From the assistant', order: 1);

      await templates.refresh();

      expect(templates.map((each) => each.name), ['Push', 'From the assistant']);
      expect(probe.notifications, greaterThan(0));
      expect(mirror.rows.keys, containsAll(['t1', 't2']));
    });

    test('a template replaced elsewhere reads as the server has it', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.rows['t1'] = _template('t1', 'Push, by the assistant');

      await templates.refresh();

      expect(templates.lookup('t1')?.name, 'Push, by the assistant');
      expect(mirror.rows['t1']?.name, 'Push, by the assistant');
      expect(templates, hasLength(1));
    });

    test('a folder made elsewhere shows, and one removed there goes', () async {
      folders.onServer.add(fldr(id: 'f1', name: 'Old'));
      final templates = await launched([]);
      expect(templates.folders.map((each) => each.name), ['Old']);

      folders.onServer
        ..clear()
        ..add(fldr(id: 'f2', name: 'From the assistant'));
      await templates.refresh();

      expect(templates.folders.map((each) => each.name), ['From the assistant']);
      expect(folders.mirrored.map((each) => each.id), ['f2']);
    });

    test('an assigned template is still assigned after it was replaced', () async {
      const coach = {'id': 'coach-1', 'username': 'Muffin'};
      final templates = await launched([_template('t1', 'Push', assignedBy: coach)]);
      server.rows['t1'] = _template('t1', 'Push, by the assistant', assignedBy: coach);

      await templates.refresh();

      final replaced = templates.lookup('t1')!;
      expect(replaced.name, 'Push, by the assistant');
      expect(replaced.isAssigned, isTrue);
      expect(replaced.assignedBy?.id, 'coach-1');
      expect(mirror.rows['t1']?.isAssigned, isTrue);
    });

    test('reads nothing for an anonymous session', () async {
      final templates = build(remote: RemoteAccess(allowed: false))..userId = uid;
      await templates.init();
      server.reads = 0;

      await templates.refresh();

      expect(server.reads, 0);
    });

    test('reads nothing before the launch has read the device', () async {
      final templates = build()..userId = uid;

      await templates.refresh();

      expect(server.reads, 0);
    });

    test('a second asker joins the read in flight', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.reads = 0;
      final gate = Completer<void>();
      server.gate = gate.future;

      final first = templates.refresh();
      final second = templates.refresh();
      gate.complete();
      await (first, second).wait;

      expect(server.reads, 1);
    });

    test('a read that fails is reported and leaves what is held', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;

      await templates.refresh();

      expect(templates.lookup('t1')?.name, 'Push');
      expect(errors, isNotEmpty);
    });

    test("the last session's read does not stand in for the next one's", () async {
      final templates = await launched([_template('t1', 'Push')]);
      final gate = Completer<void>();
      server.gate = gate.future;
      final stale = templates.refresh();

      templates.onSignOut();
      // the fake mirror holds one account's rows
      mirror.rows.clear();
      templates.userId = 'u2';
      server.rows
        ..clear()
        ..['n1'] = _template('n1', 'Theirs');
      final launch = templates.init();
      gate.complete();
      await (stale, launch).wait;

      expect(templates.map((each) => each.name), ['Theirs']);
    });
  });

  group('a change made with the server out of reach', () {
    test('stays on the device and is marked as owed, from the copy it started from', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;

      await rename(templates, 't1', 'Push, heavier');

      expect(templates.lookup('t1')?.name, 'Push, heavier');
      expect(mirror.rows['t1']?.name, 'Push, heavier');
      expect(unsent.bases['t1']?.name, 'Push');
    });

    test('a second change keeps the first base', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;

      await rename(templates, 't1', 'Push, heavier');
      await rename(templates, 't1', 'Push, heavier still');

      expect(unsent.bases['t1']?.name, 'Push');
    });

    test('one the server refuses is not owed: asking again gets the same answer', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.refusal = refusedAs({'code': 'invalid'});

      await rename(templates, 't1', 'Push, heavier');

      expect(unsent.bases, isEmpty);
    });

    test('a template the server never had is not marked: there is nothing it started from', () async {
      final templates = await launched([]);
      server.down = true;

      await templates.duplicate(
        tmpl(id: 's1', name: 'Sample'),
        name: 'Mine',
      );

      expect(unsent.bases, isEmpty);
    });

    test('an anonymous session marks nothing: its whole store goes up with the account', () async {
      mirror.rows['t1'] = _template('t1', 'Push');
      final templates = build(remote: RemoteAccess(allowed: false))..userId = uid;
      await templates.init();

      await rename(templates, 't1', 'Push, heavier');

      expect(unsent.bases, isEmpty);
    });

    test('an account whose server is closed for now owes it', () async {
      final access = RemoteAccess();
      server.rows['t1'] = _template('t1', 'Push');
      final templates = build(remote: access)..userId = uid;
      await templates.init();
      access.replaying = true;

      await rename(templates, 't1', 'Push, heavier');

      expect(unsent.bases['t1']?.name, 'Push');
    });

    test('is sent by the next read when nobody else touched the template', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');
      server.down = false;

      await templates.refresh();

      expect(server.rows['t1']?.name, 'Push, heavier');
      expect(templates.lookup('t1')?.name, 'Push, heavier');
      expect(templates, hasLength(1));
      expect(unsent.bases, isEmpty);
    });

    test('is sent by the next launch too', () async {
      final first = await launched([_template('t1', 'Push')]);
      server.down = true;
      await rename(first, 't1', 'Push, heavier');
      server.down = false;

      final relaunched = build()..userId = uid;
      await relaunched.init();

      expect(server.rows['t1']?.name, 'Push, heavier');
      expect(relaunched.lookup('t1')?.name, 'Push, heavier');
      expect(unsent.bases, isEmpty);
    });

    test('replaced on the server meanwhile: both are kept, the device\'s beside it under its own name', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');
      server.down = false;
      server.rows['t1'] = _template('t1', 'Push, by the assistant');

      await templates.refresh();

      expect(templates.lookup('t1')?.name, 'Push, by the assistant');
      final kept = templates.where((each) => each.id != 't1').single;
      expect(kept.name, 'Your changes: Push, heavier');
      // the copy went up as a template of its own
      expect(server.rows.values.map((each) => each.name), containsAll(['Push, by the assistant', kept.name]));
      expect(unsent.bases, isEmpty);
    });

    test("the kept copy carries the device's exercises and sets", () async {
      final bench = ex('Bench press');
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;
      templates.editable = templates.lookup('t1')!..append(wEx(bench, sets: 3));
      await templates.saveEditable();
      server.down = false;
      server.rows['t1'] = _template('t1', 'Push, by the assistant');

      await templates.refresh();

      final kept = templates.where((each) => each.id != 't1').single;
      expect(kept.single.exercise.id, bench.id);
      expect(kept.single, hasLength(3));
      expect(templates.lookup('t1'), isEmpty);
    });

    test("the kept copy is the user's own, whoever assigned the one it was made from", () async {
      const coach = {'id': 'coach-1', 'username': 'Muffin'};
      final templates = await launched([_template('t1', 'Push', assignedBy: coach)]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');
      server.down = false;
      server.rows['t1'] = _template('t1', 'Push, by the assistant', assignedBy: coach);

      await templates.refresh();

      expect(templates.lookup('t1')?.isAssigned, isTrue);
      expect(templates.where((each) => each.id != 't1').single.isAssigned, isFalse);
    });

    test('a copy the server will not take still stays on the device', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');
      server.down = false;
      server.rows['t1'] = _template('t1', 'Push, by the assistant');
      server.createRefusal = refusedAs({'code': 'limit_reached'});

      await templates.refresh();

      expect(
        templates.map((each) => each.name),
        containsAll(['Push, by the assistant', 'Your changes: Push, heavier']),
      );
      expect(mirror.rows.values.map((each) => each.name), contains('Your changes: Push, heavier'));
    });

    test('the server already has the change (only its answer was lost): nothing is copied', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');
      server.down = false;
      server.rows['t1'] = _template('t1', 'Push, heavier');

      await templates.refresh();

      expect(templates.map((each) => each.name), ['Push, heavier']);
      expect(server.writes, 0);
      expect(unsent.bases, isEmpty);
    });

    test('with a base that cannot be read, both are kept', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');
      server.down = false;
      unsent.unreadable.add('t1');

      await templates.refresh();

      expect(templates.map((each) => each.name), containsAll(['Push', 'Your changes: Push, heavier']));
    });

    test('waits as it is until the app has said what to call the copy', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');
      server.down = false;
      server.rows['t1'] = _template('t1', 'Push, by the assistant');
      templates.keptName = null;

      await templates.refresh();

      expect(templates.map((each) => each.name), ['Push, heavier']);
      expect(unsent.bases.keys, ['t1']);

      templates.keptName = (name) => 'Your changes: $name';
      await templates.refresh();

      expect(
        templates.map((each) => each.name),
        containsAll(['Push, by the assistant', 'Your changes: Push, heavier']),
      );
    });

    test('still out of reach at the next read: nothing changes, and it is still owed', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');

      await templates.refresh();

      expect(templates.lookup('t1')?.name, 'Push, heavier');
      expect(unsent.bases['t1']?.name, 'Push');
    });

    test('the other templates are read as usual beside one that is owed', () async {
      final templates = await launched([_template('t1', 'Push'), _template('t2', 'Pull', order: 1)]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');
      server.down = false;
      server.rows['t2'] = _template('t2', 'Pull, by the assistant', order: 1);

      await templates.refresh();

      expect(templates.lookup('t1')?.name, 'Push, heavier');
      expect(templates.lookup('t2')?.name, 'Pull, by the assistant');
    });

    test("a session of a coach's copy replaced meanwhile waits to be chosen, by that rule", () async {
      final shared = _Shared();
      final templates = await launched([_template('t1', 'Day A', programId: 'p1')]);
      templates.shared = shared;
      server.down = true;
      await rename(templates, 't1', 'Day A (mine)');
      server.down = false;
      server.rows['t1'] = _template('t1', 'Day A (coach)', programId: 'p1');

      await templates.refresh();

      expect(shared.lost.single.name, 'Day A (mine)');
      expect(templates.map((each) => each.name), ['Day A (coach)']);
    });

    test('the kept copy is the whole template: plans, notes, and nothing of where it came from', () async {
      final bench = ex('Bench press');
      final planned = wEx(bench, sets: 2)
        ..rest = 90
        ..note = 'Elbows in';
      final templates = await launched([_template('t1', 'Push', programId: 'p1', note: 'Big lifts')]);
      server.down = true;
      templates.editable = templates.lookup('t1')!..append(planned);
      await templates.saveEditable();
      server.down = false;
      server.rows['t1'] = _template('t1', 'Push, by the assistant', programId: 'p1');

      await templates.refresh();

      final kept = templates.where((each) => each.id != 't1').single;
      expect(kept.note, 'Big lifts');
      expect(kept.single.rest, 90);
      expect(kept.single.note, 'Elbows in');
      expect(kept.single, hasLength(2));
      expect(kept.programId, isNull);
      // under ids of its own, so the server takes it as a new template
      expect(kept.single.id, isNot(planned.id));
      expect(kept.single.map((set) => set.id), isNot(containsAll(planned.map((set) => set.id))));
    });

    test('a read cut short after the copy was made makes no second copy', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');
      server.down = false;
      server.rows['t1'] = _template('t1', 'Push, by the assistant');
      // the copy reaches the device and not the server
      server.createDown = true;

      await templates.refresh();
      expect(unsent.bases, isEmpty);
      server.createDown = false;
      final relaunched = build()..userId = uid;
      await relaunched.init();

      expect(relaunched.where((each) => each.name == 'Your changes: Push, heavier'), hasLength(1));
      expect(relaunched.lookup('t1')?.name, 'Push, by the assistant');
    });

    test('a change the server refuses when it is sent is kept as a copy, and not sent again', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');
      server.down = false;
      server.refusal = refusedAs({'code': 'invalid'});

      await templates.refresh();

      expect(templates.lookup('t1')?.name, 'Push');
      expect(templates.map((each) => each.name), contains('Your changes: Push, heavier'));
      expect(unsent.bases, isEmpty);

      final edits = server.editAttempts;
      await templates.refresh();
      expect(server.editAttempts, edits);
    });

    test('a pull of named sessions settles what one of them owes first', () async {
      final shared = _Shared();
      final templates = await launched([_template('t1', 'Day A', programId: 'p1')]);
      templates.shared = shared;
      server.down = true;
      await rename(templates, 't1', 'Day A (mine)');
      server.down = false;
      server.rows['t1'] = _template('t1', 'Day A (coach)', programId: 'p1');

      await templates.pull(['t1']);

      expect(shared.lost.single.name, 'Day A (mine)');
      expect(templates.lookup('t1')?.name, 'Day A (coach)');
      expect(unsent.bases, isEmpty);
    });

    test('a store of the row from elsewhere does not let go of what it owes', () async {
      final templates = await launched([_template('t1', 'Push')]);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');

      // as a program does when it files its sessions
      await mirror.storeTemplates([templates.lookup('t1')!], userId: uid);

      expect(unsent.bases['t1']?.name, 'Push');
    });
  });

  group('a read that lands on something done meanwhile', () {
    test('a template deleted while the read was on its way stays deleted', () async {
      final templates = await launched([_template('t1', 'Push'), _template('t2', 'Pull', order: 1)]);
      final gate = Completer<void>();
      server.gate = gate.future;

      final read = templates.refresh();
      await templates.delete(templates.lookup('t2')!);
      gate.complete();
      await read;

      expect(templates.map((each) => each.name), ['Push']);
      expect(mirror.rows.keys, ['t1']);
    });

    test('a template saved while the read was on its way keeps what was saved', () async {
      final templates = await launched([_template('t1', 'Push')]);
      final gate = Completer<void>();
      server.gate = gate.future;
      server.snapshotAtRead = true;

      final read = templates.refresh();
      await rename(templates, 't1', 'Push, heavier');
      gate.complete();
      await read;

      expect(templates.lookup('t1')?.name, 'Push, heavier');
      expect(mirror.rows['t1']?.name, 'Push, heavier');
    });

    test('the template open in the editor keeps the copy the editor is changing', () async {
      final templates = await launched([_template('t1', 'Push')]);
      final editing = templates.editable = templates.lookup('t1')!;
      server.rows['t1'] = _template('t1', 'Push, by the assistant');

      await templates.refresh();

      expect(identical(templates.lookup('t1'), editing), isTrue);

      // and a save that cannot reach the server shows, and is owed
      editing.name = 'Push, heavier';
      server.down = true;
      await templates.saveEditable();
      expect(templates.lookup('t1')?.name, 'Push, heavier');
      expect(unsent.bases.keys, ['t1']);
    });

    test('a save replaces the copy held, whichever object that is', () async {
      final templates = await launched([_template('t1', 'Push')]);
      final editing = _template('t1', 'Push, heavier');
      server.down = true;

      templates.editable = editing;
      await templates.saveEditable();

      expect(identical(templates.lookup('t1'), editing), isTrue);
      expect(templates, hasLength(1));
    });

    test('a session filed in a program here keeps its program until the launch read', () async {
      mirror.rows['t1'] = _template('t1', 'Push', programId: 'p1');
      final templates = await launched([_template('t1', 'Push', programId: 'p1')]);
      // the server has not had the filing yet
      server.rows['t1'] = _template('t1', 'Push');

      await templates.refresh();

      expect(templates.lookup('t1')?.programId, 'p1');
    });
  });

  group('without anything keeping what is owed', () {
    test('a read takes the server\'s copy as before', () async {
      final templates = await launched([_template('t1', 'Push')], keepsUnsent: false);
      server.down = true;
      await rename(templates, 't1', 'Push, heavier');
      server.down = false;

      await templates.refresh();

      expect(templates.map((each) => each.name), ['Push']);
    });
  });

  test('a duplicate carries what each exercise plans beyond its sets', () async {
    final templates = await launched([]);
    final planned = wEx(ex('Bench press'), sets: 2)..rest = 120;

    final copy = await templates.duplicate(
      tmpl(id: 's1', name: 'Sample', exercises: [planned]),
      name: 'Mine',
    );

    expect(copy.single.rest, 120);
  });
}

Template _template(
  String id,
  String name, {
  int order = 0,
  Map? assignedBy,
  String? programId,
  String? note,
}) {
  return Template.fromJson({
    'id': id,
    'name': name,
    'order': order,
    'exercises': [],
    'assignedBy': ?assignedBy,
    'programId': ?programId,
    'note': ?note,
  });
}

/// A copy as a store would hand it back: nothing shared with the original.
/// Through the row shape, not the wire's: a profile's `toMap` and `fromJson`
/// do not agree on the name's key.
Template _copy(Template template) {
  return Template.fromJson({
    ...template.toMap(),
    'assignedBy': switch (template.assignedBy) {
      final Profile profile => {'id': profile.id, 'username': profile.name, 'avatar': profile.avatar},
      null => null,
    },
  });
}

class _Mirror implements TemplateService {
  final rows = <String, Template>{};

  /// What each row owes the server: the copy its change started from. It
  /// outlives a store of the row, as in the real store, until it is cleared.
  final owed = <String, Template>{};
  var _minted = 0;

  @override
  Future<Iterable<Template>> getTemplates(String? userId) async {
    return switch (userId) {
      null => const [],
      _ => rows.values.map(_copy).toList(),
    };
  }

  @override
  Future<Template> startTemplate({int? order, String? userId}) async {
    return Template.empty(id: 'local-${_minted++}', order: order ?? 0);
  }

  @override
  Future<void> updateTemplate(Template template) async => rows[template.id] = _copy(template);

  @override
  Future<void> deleteTemplate(String templateId) async => rows.remove(templateId);

  @override
  Future<void> storeTemplates(Iterable<Template> templates, {String? userId}) async {
    if (userId == null) return;
    for (final template in templates) {
      rows[template.id] = _copy(template);
    }
  }
}

/// The marks, kept where the real store keeps them: on the mirror's rows.
class _Unsent implements UnsentTemplateService {
  final _Mirror _mirror;
  final unreadable = <String>{};

  new(this._mirror);

  Map<String, Template> get bases => _mirror.owed;

  @override
  Future<Map<String, Template?>> getUnsent(String userId) async {
    return {
      for (final MapEntry(key: id, value: base) in bases.entries) id: unreadable.contains(id) ? null : base,
    };
  }

  @override
  Future<void> markUnsent(String templateId, Template base) async => bases.putIfAbsent(templateId, () => base);

  @override
  Future<void> clearUnsent(String templateId) async => bases.remove(templateId);
}

class _Server implements RemoteTemplateService, RemoteTemplateFilingService {
  final rows = <String, Template>{};
  var down = false;

  /// Creates alone cannot reach the server.
  var createDown = false;

  /// The list answers as it stood when asked, not when the gate opened.
  var snapshotAtRead = false;
  var editAttempts = 0;
  ServerRefusal? refusal;
  ServerRefusal? createRefusal;
  Future<void>? gate;
  var reads = 0;
  var writes = 0;
  var _minted = 0;

  void _reach() {
    if (down) throw const SocketException('no route to host');
  }

  @override
  Future<Iterable<Template>?> getTemplates() async {
    reads++;
    final asked = rows.values.map(_copy).toList();
    await gate;
    _reach();
    return snapshotAtRead ? asked : rows.values.map(_copy).toList();
  }

  @override
  Future<Template> saveTemplate(Template template) async {
    _reach();
    if (createDown) throw const SocketException('no route to host');
    if (createRefusal case final ServerRefusal refused) throw refused;
    writes++;
    final saved = Template.fromJson({...template.toMap(), 'id': 'server-${_minted++}'});
    rows[saved.id] = saved;
    return _copy(saved);
  }

  @override
  Future<Template> editTemplate(Template template) async {
    editAttempts++;
    _reach();
    if (refusal case final ServerRefusal refused) throw refused;
    writes++;
    rows[template.id] = _copy(template);
    return _copy(template);
  }

  @override
  Future<Template> editSharedTemplate(Template template, {required int baseRevision, required String changeId}) {
    return editTemplate(template);
  }

  @override
  Future<bool> deleteTemplate(String templateId) async => rows.remove(templateId) != null;

  @override
  Future<Template> getTemplate(String templateId) async => _copy(rows[templateId]!);

  @override
  Future<Template> moveTemplate(Template template, {required String? folderId}) async => template;
}

/// The folders, on the server and in the mirror.
class _Folders {
  final onServer = <TemplateFolder>[];
  final mirrored = <TemplateFolder>[];
}

class _LocalFolders implements LocalTemplateFolderService {
  final _Folders _folders;

  new(this._folders);

  @override
  Future<Iterable<TemplateFolder>> getFolders(String userId) async => _folders.mirrored.toList();

  @override
  Future<void> storeFolders(Iterable<TemplateFolder> folders, String userId) async {
    _folders.mirrored
      ..clear()
      ..addAll(folders);
  }

  @override
  Future<void> storeFolder(TemplateFolder folder, String userId) async => _folders.mirrored.add(folder);

  @override
  Future<void> deleteFolder(String folderId, String userId) async {
    _folders.mirrored.removeWhere((each) => each.id == folderId);
  }
}

class _RemoteFolders implements ApiTemplateFolderService {
  final _Folders _folders;

  new(this._folders);

  @override
  Future<Iterable<TemplateFolder>> getFolders({required String userId}) async => _folders.onServer.toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoSamples implements RemoteConfigService {
  @override
  Future<Map> getRemoteConfig() async => const {};

  @override
  Future<Iterable<Template>> getSampleTemplates() async => const [];
}

class _Shared implements SharedSessions {
  final lost = <Template>[];

  @override
  int? baseRevisionOf(Template session) {
    return switch (session.programId) {
      String() => 1,
      null => null,
    };
  }

  @override
  Future<void> beaten(Template mine) async => lost.add(mine);
}
