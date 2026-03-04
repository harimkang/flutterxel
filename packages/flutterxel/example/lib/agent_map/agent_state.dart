enum AgentZone { idle, work, error }

enum AgentAnimationState { idle, walk, jump, run, action, hurt }

class AgentState {
  const AgentState({
    required this.zone,
    required this.animation,
    required this.frameInAnimation,
  });

  final AgentZone zone;
  final AgentAnimationState animation;
  final int frameInAnimation;
}
