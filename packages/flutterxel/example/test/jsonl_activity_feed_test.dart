import 'package:flutter_test/flutter_test.dart';
import 'package:flutterxel_example/agent_map/activity_feed.dart';
import 'package:flutterxel_example/agent_map/agent_state.dart';
import 'package:flutterxel_example/agent_map/jsonl_activity_feed.dart';

void main() {
  test('maps tool status JSONL lines to idle/work/error deterministically', () {
    const jsonl = '''
{"status":"idle"}
{"status":"running"}
{"status":"error"}
{"status":"unknown"}
''';

    final zones = JsonlActivityFeed.parseToolZones(jsonl);
    expect(zones, <AgentZone>[
      AgentZone.idle,
      AgentZone.work,
      AgentZone.error,
      AgentZone.error,
    ]);
    expect(JsonlActivityFeed.parseToolZones(jsonl), zones);
  });

  test('jsonl activity feed stream emits mapped zones in order', () async {
    const jsonl = '''
{"tool_status":"queued"}
{"tool_status":"completed"}
{"tool_status":"failed"}
''';
    final feed = JsonlActivityFeed.fromText(jsonl);
    final zones = await feed.zones().toList();
    expect(zones, <AgentZone>[AgentZone.idle, AgentZone.work, AgentZone.error]);
  });

  test('activity feed can be treated as swappable interface', () async {
    const jsonl = '{"status":"running"}';
    final ActivityFeed feed = JsonlActivityFeed.fromText(jsonl);
    final zones = await feed.zones().toList();
    expect(zones, <AgentZone>[AgentZone.work]);
  });
}
