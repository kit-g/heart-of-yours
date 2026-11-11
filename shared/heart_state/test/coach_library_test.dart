import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The server's side, in memory: a document per program, a new version per
/// save, as heart-api keeps them.
class _Server implements CoachLibraryService {
  final bodies = <String, Map<String, dynamic>>{};
  final versions = <String, int>{};
  final saves = <Map<String, dynamic>>[];
  final sent = <(String, List<String>)>[];
  final deleted = <String>[];
  var clock = DateTime.utc(2026, 11, 10);

  Object? refuse;
  var reads = 0;

  CoachProgram _row(String id, {bool body = true}) {
    return CoachProgram(
      id: id,
      name: bodies[id]!['name'] as String,
      version: versions[id]!,
      body: body ? bodies[id] : null,
      updatedAt: clock,
    );
  }

  @override
  Future<({List<CoachProgram> items, String? cursor})> getLibraryPrograms({String? cursor}) async {
    reads++;
    if (refuse case final refusal?) throw refusal;
    final ids = bodies.keys.toList();
    final from = int.parse(cursor ?? '0');
    return (
      items: [for (final id in ids.skip(from).take(1)) _row(id, body: false)],
      cursor: from + 1 < ids.length ? '${from + 1}' : null,
    );
  }

  @override
  Future<CoachProgram> getLibraryProgram(String programId) async {
    reads++;
    if (refuse case final refusal?) throw refusal;
    return _row(programId);
  }

  @override
  Future<CoachProgram> saveLibraryProgram(String programId, Map<String, dynamic> body) async {
    if (refuse case final refusal?) throw refusal;
    saves.add(body);
    bodies[programId] = body;
    versions[programId] = (versions[programId] ?? 0) + 1;
    clock = clock.add(const Duration(minutes: 1));
    return _row(programId);
  }

  @override
  Future<void> deleteLibraryProgram(String programId) async {
    if (refuse case final refusal?) throw refusal;
    deleted.add(programId);
  }

  @override
  Future<List<CoachProgramHolder>> getLibraryHolders(String programId) async => const [];

  @override
  Future<List<ProgramDelivery>> sendLibraryProgram(String programId, Iterable<String> connectionIds) async {
    sent.add((programId, connectionIds.toList()));
    return [for (final id in connectionIds) ProgramDelivery(connectionId: id, delivered: true, programId: 'copy-$id')];
  }
}

final _squat = Exercise(name: 'Squat', category: .barbell, target: .legs);

void main() {
  late _Server server;
  late CoachLibrary library;

  Exercise? exerciseOf(String id) => id == _squat.id ? _squat : null;

  setUp(() {
    server = _Server();
    library = CoachLibrary(service: server, exerciseOf: exerciseOf);
  });

  /// A program of one session, Day A: a squat for three sets of five.
  Future<CoachLibraryProgram> written() async {
    final program = await library.create(Program(name: 'Strength block', perWeek: 2, weeks: 4));
    library.editSession(program);
    library.editable!.name = 'Day A';
    await library.add(_squat);
    final squat = library.editable!.single;
    squat.first.setMeasurements(reps: 5);
    library
      ..addSet(squat)
      ..addSet(squat);
    await library.saveEditable();
    return library.lookup(program.id)!;
  }

  test('reads nothing with the remote leg closed', () async {
    library = CoachLibrary(service: server, exerciseOf: exerciseOf, remote: RemoteAccess(allowed: false));
    await library.load();
    expect(server.reads, 0);
    expect(library.status, CoachingStatus.idle);
  });

  test('reads every page', () async {
    server
      ..bodies.addAll({
        'a': {'name': 'Strength block'},
        'b': {'name': 'Hypertrophy'},
      })
      ..versions.addAll({'a': 1, 'b': 3});

    await library.load();

    expect(library.status, CoachingStatus.loaded);
    expect([for (final each in library.programs) each.name], unorderedEquals(['Strength block', 'Hypertrophy']));
  });

  test('a library that cannot be read says so', () async {
    server.refuse = {'code': 'boom'};
    await library.load();
    expect(library.status, CoachingStatus.failed);
  });

  test('a new program is saved at once, empty, and is first in the library', () async {
    final program = await library.create(Program(name: 'Strength block', perWeek: 2, weeks: 4));

    expect(isUuidV7(program.id), isTrue);
    expect(program.version, 1);
    expect(program.sessions, isEmpty);
    expect(server.saves.single, {'name': 'Strength block', 'perWeek': 2, 'weeks': 4, 'rules': {}, 'sessions': []});
    expect(library.programs.single.id, program.id);
  });

  test('a session written in the editor is saved into its program, named by exercise id', () async {
    final program = await written();

    expect(program.version, 2);
    final [session] = program.sessions;
    expect(session.name, 'Day A');
    expect(session.single.exercise.name, 'Squat');
    expect(session.single.length, 3);
    expect(session.single.map((set) => set.reps), [5, 5, 5]);

    final [body] = (server.saves.last['sessions'] as List).cast<Map>();
    final [exercise] = (body['exercises'] as List).cast<Map>();
    expect(exercise['exercise'], _squat.id);
    expect(exercise.containsKey('start'), isFalse);
    expect(library.editable, isNull);
  });

  test('editing a session works on a copy, and leaving it changes nothing', () async {
    final program = await written();
    final saves = server.saves.length;

    library.editSession(program, session: program.sessions.single);
    library.addSet(library.editable!.single);
    await library.discardEditable();

    expect(library.lookup(program.id)!.sessions.single.single.length, 3);
    expect(server.saves.length, saves);
  });

  test('a session saved again stays where it was', () async {
    final program = await library.create(Program(name: 'Strength block'));
    for (final name in ['Day A', 'Day B']) {
      library.editSession(library.lookup(program.id)!);
      library.editable!.name = name;
      await library.add(_squat);
      await library.saveEditable();
    }

    final both = library.lookup(program.id)!;
    library.editSession(both, session: both.sessions.first);
    library.editable!.name = 'Day A, heavy';
    await library.saveEditable();

    expect([for (final each in library.lookup(program.id)!.sessions) each.name], ['Day A, heavy', 'Day B']);
  });

  test('sessions move and leave, each a save', () async {
    final program = await library.create(Program(name: 'Strength block'));
    for (final name in ['Day A', 'Day B', 'Day C']) {
      library.editSession(library.lookup(program.id)!);
      library.editable!.name = name;
      await library.add(_squat);
      await library.saveEditable();
    }

    await library.moveSession(library.lookup(program.id)!, 2, 0);
    expect([for (final each in library.lookup(program.id)!.sessions) each.name], ['Day C', 'Day A', 'Day B']);

    final current = library.lookup(program.id)!;
    await library.removeSession(current, current.sessions[1]);
    expect([for (final each in library.lookup(program.id)!.sessions) each.name], ['Day C', 'Day B']);
    expect([for (final each in server.saves.last['sessions'] as List) (each as Map)['name']], ['Day C', 'Day B']);
  });

  test("a save that doesn't arrive is kept here, unsaved, until a retry gets it there", () async {
    final program = await written();
    server.refuse = {'code': 'offline'};

    final saved = await library.save(program.copyWith(program: program.program.copyWith(name: 'Strength block v2')));

    expect(saved, isFalse);
    expect(library.unsaved(program.id), isTrue);
    expect(library.lookup(program.id)!.program.name, 'Strength block v2');
    // read again, it is still the device's change, not the server's older one
    expect((await library.open(program.id)).program.name, 'Strength block v2');

    server.refuse = null;
    expect(await library.retry(program.id), isTrue);
    expect(library.unsaved(program.id), isFalse);
    expect(server.bodies[program.id]!['name'], 'Strength block v2');
  });

  test('a field taken away leaves the body, and what this build cannot read stays in it', () async {
    server
      ..bodies['p'] = {
        'name': 'Strength block',
        'note': 'Four weeks',
        'weeks': 4,
        'futureField': {'kept': true},
        'sessions': [
          {
            'id': 's1',
            'name': 'Day A',
            'exercises': [
              {
                'id': 'e1',
                'exercise': 'an-exercise-this-coach-does-not-have',
                'sets': [
                  {'id': 'x1', 'reps': 5},
                ],
              },
            ],
          },
        ],
      }
      ..versions['p'] = 1;

    final program = await library.open('p');
    expect(program.program.note, 'Four weeks');
    expect(program.sessions.single.isEmpty, isTrue);

    await library.save(program.copyWith(program: program.program.without({.note, .weeks})));

    final body = server.saves.last;
    expect(body.containsKey('note'), isFalse);
    expect(body.containsKey('weeks'), isFalse);
    expect(body['futureField'], {'kept': true});
    final [session] = (body['sessions'] as List).cast<Map>();
    expect((session['exercises'] as List).single, containsPair('exercise', 'an-exercise-this-coach-does-not-have'));
  });

  test('a delete leaves the library, and a refused one leaves it as it was', () async {
    final program = await written();

    server.refuse = {'code': 'offline'};
    await expectLater(library.delete(program.id), throwsA(isA<Map>()));
    expect(library.programs, hasLength(1));

    server.refuse = null;
    await library.delete(program.id);
    expect(library.programs, isEmpty);
    expect(library.lookup(program.id), isNull);
  });

  test('a send names the connections', () async {
    final program = await written();

    final deliveries = await library.send(program.id, ['c-muffin', 'c-biscuit']);

    final [(id, connections)] = server.sent;
    expect(id, program.id);
    expect(connections, ['c-muffin', 'c-biscuit']);
    expect([for (final each in deliveries) each.programId], ['copy-c-muffin', 'copy-c-biscuit']);
  });

  test('refusals are read by their codes, and an unknown one is none of them', () {
    expect(DeliveryRefusal.of('program_limit'), DeliveryRefusal.programLimit);
    expect(DeliveryRefusal.of('something_new'), isNull);
    expect(DeliveryRefusal.of(null), isNull);
  });

  test('signing out forgets the library and the draft', () async {
    final program = await written();
    library.editSession(program);

    library.onSignOut();

    expect(library.programs, isEmpty);
    expect(library.lookup(program.id), isNull);
    expect(library.editable, isNull);
    expect(library.status, CoachingStatus.idle);
  });
}
