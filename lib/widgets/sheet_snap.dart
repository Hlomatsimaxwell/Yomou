/// Picks the size a dragged [DraggableScrollableSheet] should settle at.
///
/// [DraggableScrollableSheet] snaps on its own, but only for drags that arrive
/// through the scrollable it hands out -- and a tray's header bar is not that
/// scrollable. Both of Yomou's trays drive the sheet from their bar, and a bar
/// dragged down has to collapse the tray from wherever the list happens to be
/// scrolled to, which is the whole point of driving it by hand. So the snapping
/// has to be done here as well.
///
/// A flick travels one stop in the direction it was thrown; a drag let go
/// without a flick settles on the nearer of the two stops it sits between.
///
/// [size] is the sheet's current size as a fraction of its container,
/// [velocity] is the drag's vertical velocity in logical pixels per second
/// (positive downwards, matching [DragEndDetails.velocity]), and [stops] are
/// the sizes the sheet may come to rest at.
double sheetSnapTarget({
  required double size,
  required double velocity,
  required List<double> stops,
  double flingVelocity = 300,
  double epsilon = 0.001,
}) {
  assert(stops.isNotEmpty, 'a sheet needs somewhere to come to rest');
  final sorted = [...stops]..sort();

  if (velocity < -flingVelocity) {
    // Thrown upwards: the next stop above, or the top one if already past it.
    return sorted.firstWhere(
      (stop) => stop > size + epsilon,
      orElse: () => sorted.last,
    );
  }
  if (velocity > flingVelocity) {
    // Thrown downwards: the next stop below, or the bottom one.
    return sorted.lastWhere(
      (stop) => stop < size - epsilon,
      orElse: () => sorted.first,
    );
  }

  return sorted.reduce(
    (a, b) => (a - size).abs() <= (b - size).abs() ? a : b,
  );
}
