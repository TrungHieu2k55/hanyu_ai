class SampleQuestion {
  const SampleQuestion(
    this.prompt,
    this.choices,
    this.correct,
    this.explanation,
  );
  final String prompt, explanation;
  final List<String> choices;
  final int correct;
}
