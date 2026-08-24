/// App-wide view-zoom math (spec story 11).
///
/// Pure functions — no Flutter imports — so the bounds and stepping rules are
/// unit-testable headlessly. The controller persists the factor; the app root
/// applies it as a text scaler.
library;

/// Smallest allowed zoom factor (50%).
const kZoomMin = 0.5;

/// Largest allowed zoom factor (200%).
const kZoomMax = 2.0;

/// One keyboard step, 10% of the base scale.
const kZoomStep = 0.1;

/// Clamps [factor] into the documented range.
double clampZoom(double factor) => factor.clamp(kZoomMin, kZoomMax);

/// Moves [current] one [kZoomStep] up or down, snapping to a tenth to avoid
/// binary floating point drift (0.7 + 0.1 must be 0.8), then clamping.
double stepZoom(double current, {required bool up}) {
  final next = clampZoom(current) + (up ? kZoomStep : -kZoomStep);
  return clampZoom((next * 10).round() / 10);
}
