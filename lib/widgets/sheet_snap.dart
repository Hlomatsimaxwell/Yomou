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
}) {
  assert(stops.isNotEmpty, 'a sheet needs somewhere to come to rest');

  if (velocity < -flingVelocity) {
    return sheetNextStop(size: size, stops: stops);
  }
  if (velocity > flingVelocity) {
    return sheetPreviousStop(size: size, stops: stops);
  }

  final sorted = [...stops]..sort();
  return sorted.reduce(
    (a, b) => (a - size).abs() <= (b - size).abs() ? a : b,
  );
}

/// The first stop above [size], or the bottom one when there is none above it.
///
/// This is what a tray tapped or flicked upwards should open to next, and it is
/// why a tray that is already past a stop never returns to it: a tray dragged
/// most of the way up opens, rather than dropping back to the halfway point it
/// passed on the way.
double sheetNextStop({
  required double size,
  required List<double> stops,
  double epsilon = 0.01,
}) {
  assert(stops.isNotEmpty, 'a sheet needs somewhere to come to rest');
  final sorted = [...stops]..sort();
  return sorted.firstWhere(
    (stop) => stop > size + epsilon,
    orElse: () => sorted.first,
  );
}

/// The first stop below [size], or the top one when there is none below it.
double sheetPreviousStop({
  required double size,
  required List<double> stops,
  double epsilon = 0.01,
}) {
  assert(stops.isNotEmpty, 'a sheet needs somewhere to come to rest');
  final sorted = [...stops]..sort();
  return sorted.lastWhere(
    (stop) => stop < size - epsilon,
    orElse: () => sorted.last,
  );
}
