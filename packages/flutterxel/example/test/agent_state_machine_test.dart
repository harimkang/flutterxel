import 'package:flutter_test/flutter_test.dart';
import 'package:flutterxel_example/agent_map/agent_state.dart';
import 'package:flutterxel_example/agent_map/agent_state_machine.dart';

void main() {
  List<AgentAnimationState> collect(
    AgentStateMachine machine,
    AgentZone zone,
    int count,
  ) {
    return List<AgentAnimationState>.generate(
      count,
      (_) => machine.advance(zone).animation,
      growable: false,
    );
  }

  test('idle zone cycles idle -> walk -> jump -> idle', () {
    final machine = AgentStateMachine();
    final states = collect(machine, AgentZone.idle, 4);
    expect(states, <AgentAnimationState>[
      AgentAnimationState.idle,
      AgentAnimationState.walk,
      AgentAnimationState.jump,
      AgentAnimationState.idle,
    ]);
  });

  test('work zone cycles run -> walk -> jump -> action -> run', () {
    final machine = AgentStateMachine();
    final states = collect(machine, AgentZone.work, 5);
    expect(states, <AgentAnimationState>[
      AgentAnimationState.run,
      AgentAnimationState.walk,
      AgentAnimationState.jump,
      AgentAnimationState.action,
      AgentAnimationState.run,
    ]);
  });

  test('error zone cycles hurt -> idle -> hurt -> walk -> idle', () {
    final machine = AgentStateMachine();
    final states = collect(machine, AgentZone.error, 5);
    expect(states, <AgentAnimationState>[
      AgentAnimationState.hurt,
      AgentAnimationState.idle,
      AgentAnimationState.hurt,
      AgentAnimationState.walk,
      AgentAnimationState.idle,
    ]);
  });
}
