/// Rewrites a cover URL from the small variant a source lists to the full-size
/// original the same site keeps beside it.
///
/// Two shapes dominate the sources:
///
///  * **MangaDex** stores the cover once and appends a size to serve it, e.g.
///    `.../4a74.jpg.256.jpg` for a 256px copy; the untouched file is at
///    `.../4a74.jpg`.
///  * **WordPress**, and the Madara theme built on it (ManhuaPlus, ...),
///    keeps the upload at its original path and links the generated
///    thumbnails as `<name>-<w>x<h>.<ext>`, e.g. `cover-193x278.jpg`, while the
///    original stays at `cover.jpg`.
///
/// A grid cell wants the small file — it is drawn at ~140px and the small one
/// costs a fraction of the bytes — so this is only called where the cover is
/// drawn large (the full-screen viewer, and when saving it). Returns [url]
/// unchanged when it matches neither shape, and never rewrites a URL that
/// carries a query string, since those are often signed and must be sent
/// exactly as issued.
String fullSizedImageUrl(String url) {
  if (url.isEmpty) return url;

  // MangaDex: `<file>.<ext>.<size>.<ext>` -> `<file>.<ext>`.
  final mangadex = url.replaceFirst(
    RegExp(r'\.\d{3}\.(?:jpe?g|png|webp|gif|avif)$', caseSensitive: false),
    '',
  );
  if (mangadex != url) return mangadex;

  // WordPress/Madara: drop the `-193x278` of `<name>-193x278.<ext>`.
  return url.replaceFirst(
    RegExp(r'-\d+x\d+(?=\.(?:jpe?g|png|webp|gif|avif)$)', caseSensitive: false),
    '',
  );
}
