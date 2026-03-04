import 'agent_state.dart';

abstract class ActivityFeed {
  Stream<AgentZone> zones();
}
