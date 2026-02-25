import 'dart:io';

import 'package:flutterxel_tools/flutterxel_tools.dart';

void main(List<String> args) {
  final parser = FlutterxelTools.buildParser();
  final results = parser.parse(args);
  final output = FlutterxelTools.dispatch(results);
  stdout.writeln(output);
}
