import 'package:args/args.dart';

enum FlutterxelToolCommand { run, watch, play, edit, package, app2html }

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
      _ => usage(),
    };
  }
}
