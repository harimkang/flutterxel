import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutterxel_tools/flutterxel_tools.dart';

void main() {
  test('returns usage when no command is selected', () {
    final parser = FlutterxelTools.buildParser();
    final results = parser.parse(const []);
    expect(FlutterxelTools.dispatch(results), FlutterxelTools.usage());
  });

  test('dispatches scaffolded command message', () {
    final parser = FlutterxelTools.buildParser();
    final results = parser.parse(const ['run']);
    expect(
      FlutterxelTools.dispatch(results),
      'run is scaffolded but not implemented yet.',
    );
  });

  test('supports build-native command for rust core artifact workflow', () {
    final parser = FlutterxelTools.buildParser();
    final results = parser.parse(const ['build-native']);
    expect(FlutterxelTools.dispatch(results), contains('build-native'));
  });

  test('execute runs build-native script with forwarded args', () async {
    String? executable;
    List<String>? arguments;

    final exitCode = await FlutterxelTools.execute(
      const ['build-native', '--android'],
      runProcess: (exec, args) async {
        executable = exec;
        arguments = args;
        return ProcessResult(12345, 0, 'ok', '');
      },
      onStdout: (_) {},
      onStderr: (_) {},
    );

    expect(exitCode, 0);
    expect(executable, 'bash');
    expect(arguments, isNotNull);
    expect(arguments!.first, contains('build_rust_core_artifacts.sh'));
    expect(arguments, contains('--android'));
  });
}
