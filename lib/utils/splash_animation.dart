/// `animate` mirrors the JSX helper from the design prototype. Given a value
/// range and a time window, it returns a function that maps a global time `t`
/// to an eased value, clamped to `[from, to]` outside the window.
typedef Easing = double Function(double t);
typedef Animator = double Function(double t);

Animator animate({
  required double from,
  required double to,
  required double start,
  required double end,
  Easing ease = linear,
}) {
  return (double t) {
    if (t <= start) return from;
    if (t >= end) return to;
    final p = (t - start) / (end - start);
    return from + (to - from) * ease(p);
  };
}

double clampD(double v, double mn, double mx) =>
    v < mn ? mn : (v > mx ? mx : v);

double linear(double t) => t;

double easeOutCubic(double t) {
  final u = 1 - t;
  return 1 - u * u * u;
}

double easeInCubic(double t) => t * t * t;

double easeInOutCubic(double t) {
  if (t < 0.5) return 4 * t * t * t;
  final u = -2 * t + 2;
  return 1 - (u * u * u) / 2;
}

/// easeOutBack with the standard `s` overshoot.
double easeOutBack(double t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final u = t - 1;
  return 1 + c3 * u * u * u + c1 * u * u;
}
