enum MemoryRating {
  forgot(0, 'Quên'),
  hard(3, 'Khó'),
  remembered(4, 'Nhớ'),
  easy(5, 'Dễ');

  const MemoryRating(this.quality, this.label);
  final int quality;
  final String label;
}

class ReviewSchedule {
  const ReviewSchedule({
    this.repetitions = 0,
    this.intervalDays = 0,
    this.ease = 2.5,
  });
  final int repetitions, intervalDays;
  final double ease;
  ReviewSchedule next(MemoryRating rating) {
    final q = rating.quality;
    final interval = q < 3
        ? 1
        : repetitions == 0
        ? 1
        : repetitions == 1
        ? 6
        : (intervalDays * ease + .5).floor().clamp(1, 1000000);
    final difference = 5 - q;
    final nextEase = (ease + .1 - difference * (.08 + difference * .02)).clamp(
      1.3,
      double.infinity,
    );
    return ReviewSchedule(
      repetitions: q < 3 ? 0 : repetitions + 1,
      intervalDays: interval,
      ease: nextEase,
    );
  }
}
