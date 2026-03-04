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

  test(
    'supports release-check command for tag/version validation workflow',
    () {
      final parser = FlutterxelTools.buildParser();
      final results = parser.parse(const ['release-check']);
      expect(FlutterxelTools.dispatch(results), contains('release-check'));
    },
  );

  test('supports release-bump command for pre-tag version automation', () {
    final parser = FlutterxelTools.buildParser();
    final results = parser.parse(const ['release-bump']);
    expect(FlutterxelTools.dispatch(results), contains('release-bump'));
  });

  test('supports pixel-snap command for asset preprocessing workflow', () {
    final parser = FlutterxelTools.buildParser();
    final results = parser.parse(const [
      'pixel-snap',
      '--input',
      'assets/raw/hero.png',
      '--output',
      'assets/pixel/hero.png',
      '--colors',
      '16',
    ]);
    expect(FlutterxelTools.dispatch(results), contains('pixel-snap'));
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

  test('execute runs release-check script with forwarded tag', () async {
    String? executable;
    List<String>? arguments;

    final exitCode = await FlutterxelTools.execute(
      const ['release-check', '--tag', 'v0.0.1'],
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
    expect(arguments!.first, contains('check_release_versions.sh'));
    expect(arguments, containsAll(<String>['--tag', 'v0.0.1']));
  });

  test('execute runs release-check script with forwarded version', () async {
    String? executable;
    List<String>? arguments;

    final exitCode = await FlutterxelTools.execute(
      const ['release-check', '--version', '0.0.1'],
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
    expect(arguments!.first, contains('check_release_versions.sh'));
    expect(arguments, containsAll(<String>['--version', '0.0.1']));
  });

  test('execute runs release-bump script with forwarded version', () async {
    String? executable;
    List<String>? arguments;

    final exitCode = await FlutterxelTools.execute(
      const ['release-bump', '--version', '0.0.2'],
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
    expect(arguments!.first, contains('bump_release_versions.sh'));
    expect(arguments, containsAll(<String>['--version', '0.0.2']));
  });
}
