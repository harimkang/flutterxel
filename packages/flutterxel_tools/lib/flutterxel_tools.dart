import 'dart:io';

import 'package:args/args.dart';

enum FlutterxelToolCommand {
  run,
  watch,
  play,
  edit,
  package,
  app2html,
  buildNative,
  releaseCheck,
  releaseBump,
}

class FlutterxelTools {
  FlutterxelTools._();

  static ArgParser buildParser() {
    final parser = ArgParser();
    parser.addFlag('help', abbr: 'h', negatable: false);
    parser.addCommand('run');
    parser.addCommand('watch');
    parser.addCommand('play');
    parser.addCommand('edit');
    parser.addCommand('package');
    parser.addCommand('app2html');
    final buildNative = parser.addCommand('build-native');
    buildNative.addFlag(
      'android',
      negatable: false,
      help: 'Build Android shared libraries.',
    );
    buildNative.addFlag(
      'ios',
      negatable: false,
      help: 'Build iOS static libraries and xcframework.',
    );
    buildNative.addFlag(
      'all',
      negatable: false,
      help: 'Build both Android and iOS artifacts.',
    );
    buildNative.addOption(
      'out-dir',
      help: 'Optional output directory for packaged artifacts.',
    );
    final releaseCheck = parser.addCommand('release-check');
    releaseCheck.addOption(
      'tag',
      help: 'Release tag to validate (for example v0.1.0).',
    );
    releaseCheck.addOption(
      'version',
      help: 'Version to validate before tag creation (for example 0.1.0).',
    );
    final releaseBump = parser.addCommand('release-bump');
    releaseBump.addOption(
      'version',
      help: 'Version to set (for example 0.1.0).',
    );
    return parser;
  }

  static String usage() => buildParser().usage;

  static String dispatch(ArgResults results) {
    final command = results.command?.name;
    if (results['help'] == true || command == null) {
      return usage();
    }

    return switch (command) {
      'run' => 'run is scaffolded but not implemented yet.',
      'watch' => 'watch is scaffolded but not implemented yet.',
      'play' => 'play is scaffolded but not implemented yet.',
      'edit' => 'edit is scaffolded but not implemented yet.',
      'package' => 'package is scaffolded but not implemented yet.',
      'app2html' => 'app2html is scaffolded but not implemented yet.',
      'build-native' =>
        'build-native scaffold: run packages/flutterxel_tools/tool/build_rust_core_artifacts.sh',
      'release-check' =>
        'release-check scaffold: run packages/flutterxel_tools/tool/check_release_versions.sh',
      'release-bump' =>
        'release-bump scaffold: run packages/flutterxel_tools/tool/bump_release_versions.sh',
      _ => usage(),
    };
  }

  static String _buildNativeScriptPath() {
    final sep = Platform.pathSeparator;
    final candidates = <String>[
      '${Directory.current.path}${sep}packages${sep}flutterxel_tools${sep}tool${sep}build_rust_core_artifacts.sh',
      '${Directory.current.path}${sep}tool${sep}build_rust_core_artifacts.sh',
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return candidates.first;
  }

  static String _releaseCheckScriptPath() {
    final sep = Platform.pathSeparator;
    final candidates = <String>[
      '${Directory.current.path}${sep}packages${sep}flutterxel_tools${sep}tool${sep}check_release_versions.sh',
      '${Directory.current.path}${sep}tool${sep}check_release_versions.sh',
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return candidates.first;
  }

  static String _releaseBumpScriptPath() {
    final sep = Platform.pathSeparator;
    final candidates = <String>[
      '${Directory.current.path}${sep}packages${sep}flutterxel_tools${sep}tool${sep}bump_release_versions.sh',
      '${Directory.current.path}${sep}tool${sep}bump_release_versions.sh',
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return candidates.first;
  }

  static Future<int> execute(
    List<String> args, {
    Future<ProcessResult> Function(String executable, List<String> arguments)?
    runProcess,
    void Function(String message)? onStdout,
    void Function(String message)? onStderr,
  }) async {
    runProcess ??= (executable, arguments) =>
        Process.run(executable, arguments);
    onStdout ??= (message) => stdout.writeln(message);
    onStderr ??= (message) => stderr.writeln(message);

    final parser = buildParser();
    late final ArgResults results;
    try {
      results = parser.parse(args);
    } on FormatException catch (error) {
      onStderr(error.message);
      onStdout(parser.usage);
      return 64;
    }

    final command = results.command?.name;
    if (results['help'] == true || command == null) {
      onStdout(parser.usage);
      return 0;
    }

    if (command != 'build-native' &&
        command != 'release-check' &&
        command != 'release-bump') {
      onStdout(dispatch(results));
      return 0;
    }

    final commandArgs = results.command!;
    final scriptPath = switch (command) {
      'build-native' => _buildNativeScriptPath(),
      'release-check' => _releaseCheckScriptPath(),
      'release-bump' => _releaseBumpScriptPath(),
      _ => '',
    };
    if (!File(scriptPath).existsSync()) {
      onStderr('$command script not found: $scriptPath');
      return 66;
    }

    final forwarded = <String>[
      if (command == 'build-native' && commandArgs['android'] == true)
        '--android',
      if (command == 'build-native' && commandArgs['ios'] == true) '--ios',
      if (command == 'build-native' && commandArgs['all'] == true) '--all',
    ];
    if (command == 'build-native') {
      final outDir = commandArgs['out-dir'] as String?;
      if (outDir != null && outDir.isNotEmpty) {
        forwarded.addAll(['--out-dir', outDir]);
      }
    } else if (command == 'release-check') {
      final tag = commandArgs['tag'] as String?;
      if (tag != null && tag.isNotEmpty) {
        forwarded.addAll(['--tag', tag]);
      }
      final version = commandArgs['version'] as String?;
      if (version != null && version.isNotEmpty) {
        forwarded.addAll(['--version', version]);
      }
    } else if (command == 'release-bump') {
      final version = commandArgs['version'] as String?;
      if (version != null && version.isNotEmpty) {
        forwarded.addAll(['--version', version]);
      }
    }
    forwarded.addAll(commandArgs.rest);

    final result = await runProcess('bash', [scriptPath, ...forwarded]);

    final stdOutText = result.stdout.toString().trim();
    if (stdOutText.isNotEmpty) {
      onStdout(stdOutText);
    }

    final stdErrText = result.stderr.toString().trim();
    if (stdErrText.isNotEmpty) {
      onStderr(stdErrText);
    }

    return result.exitCode;
  }
}
