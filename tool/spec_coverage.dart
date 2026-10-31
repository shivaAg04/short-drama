// Lists every acceptance criterion in specs/ and the tests tagged with it.
//
//   dart run tool/spec_coverage.dart           report
//   dart run tool/spec_coverage.dart --strict  also exit 1 if any is uncovered
//
// Criteria marked *(manual)* in a spec are judged on a device and are
// reported separately rather than as missing.
import 'dart:io';

final _criterion = RegExp(
  r'^- \*\*([A-Z]+-\d+)\*\*( \*\(manual\)\*)?',
  multiLine: true,
);
final _tag = RegExp(r'\[([A-Z]+-\d+)\]');
final _testName = RegExp(
  r'''(?:test|blocTest<[^>]*>|testWidgets)\(\s*['"]([^'"]+)''',
);

void main(List<String> args) {
  final ids = <String>[];
  final manual = <String>{};
  for (final file in _files('specs', '.md')) {
    for (final m in _criterion.allMatches(file.readAsStringSync())) {
      ids.add(m[1]!);
      if (m[2] != null) manual.add(m[1]!);
    }
  }

  final covered = <String, Set<String>>{};
  for (final file in _files('test', '_test.dart')) {
    for (final m in _testName.allMatches(file.readAsStringSync())) {
      for (final tag in _tag.allMatches(m[1]!)) {
        covered.putIfAbsent(tag[1]!, () => {}).add(file.path);
      }
    }
  }

  var missing = 0;
  for (final id in ids) {
    final files = covered[id];
    final isManual = manual.contains(id);
    if (files == null && !isManual) missing++;
    final mark = files != null ? '✓ ' : (isManual ? 'm ' : '  ');
    final where = files?.join(', ') ?? (isManual ? '(manual, on device)' : '');
    stdout.writeln('$mark${id.padRight(9)}$where');
  }

  final automated = ids.length - manual.length;
  stdout.writeln(
    '\n${automated - missing}/$automated automated criteria covered by tests, '
    '${manual.length} manual',
  );

  final unknown = covered.keys.toSet().difference(ids.toSet());
  if (unknown.isNotEmpty) {
    stderr.writeln('Tests tag unknown criteria: ${unknown.join(', ')}');
    exitCode = 1;
  }
  if (args.contains('--strict') && missing > 0) exitCode = 1;
}

Iterable<File> _files(String dir, String suffix) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith(suffix))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
