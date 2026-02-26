import 'dart:io';

import 'package:flutterxel_tools/flutterxel_tools.dart';

Future<void> main(List<String> args) async {
  final exitCode = await FlutterxelTools.execute(args);
  if (exitCode != 0) {
    exit(exitCode);
  }
}
