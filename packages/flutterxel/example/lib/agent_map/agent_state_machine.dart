import 'agent_state.dart';

class AgentStateMachine {
  AgentStateMachine({this.ticksPerState = 1})
    : assert(ticksPerState > 0, 'ticksPerState must be greater than zero.');

  final int ticksPerState;

  static const Map<AgentZone, List<AgentAnimationState>> _zoneCycles = {
    AgentZone.idle: <AgentAnimationState>[
      AgentAnimationState.idle,
      AgentAnimationState.walk,
      AgentAnimationState.jump,
    ],
    AgentZone.work: <AgentAnimationState>[
      AgentAnimationState.run,
      AgentAnimationState.walk,
      AgentAnimationState.jump,
      AgentAnimationState.action,
    ],
    AgentZone.error: <AgentAnimationState>[
      AgentAnimationState.hurt,
      AgentAnimationState.idle,
      AgentAnimationState.hurt,
      AgentAnimationState.walk,
      AgentAnimationState.idle,
    ],
  };

  AgentZone? _zone;
  int _stateIndex = 0;
  int _tickInState = 0;

  AgentState advance(AgentZone zone) {
    if (_zone != zone) {
      _zone = zone;
      _stateIndex = 0;
      _tickInState = 0;
    }

    final cycle = _zoneCycles[zone]!;
    final animation = cycle[_stateIndex];
    final state = AgentState(
      zone: zone,
      animation: animation,
      frameInAnimation: _tickInState,
    );

    _tickInState += 1;
    if (_tickInState >= ticksPerState) {
      _tickInState = 0;
      _stateIndex = (_stateIndex + 1) % cycle.length;
    }

    return state;
  }
}
