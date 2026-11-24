class Scenario {
  const Scenario(
    this.id,
    this.title,
    this.role,
    this.partner,
    this.goal,
    this.opening,
    this.reply,
    this.suggestion, {
    this.version = 'sample-v1-unreviewed',
  });
  final String version;
  final String id, title, role, partner, goal, suggestion;
  final List<String> opening, reply;
}
