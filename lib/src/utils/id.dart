String generateFiveDigitId(int seed) {
  // Deterministic-ish (but still pseudo-random per user) using a seed.
  // Ensures 10000-99999.
  final v = (seed.abs() % 90000) + 10000;
  return v.toString();
}
