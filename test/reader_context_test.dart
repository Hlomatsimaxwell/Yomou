import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/features/settings/providers/reader_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('scale mode falls back to the global default with no per-title key',
      () async {
    SharedPreferences.setMockInitialValues({'rs.scale': kScaleFitHeight});

    final ctx = await resolveReaderContext('manga-1');

    expect(ctx.settings.scaleMode, kScaleFitHeight);
    expect(ctx.overridden, isNot(contains('reader_scale_mode')));
  });

  test('a saved per-title scale mode wins over the global default', () async {
    SharedPreferences.setMockInitialValues({
      'rs.scale': kScaleFitHeight,
      'manga-1_reader_scale_mode': kScaleFitWidth,
    });

    final ctx = await resolveReaderContext('manga-1');

    expect(ctx.settings.scaleMode, kScaleFitWidth);
    expect(ctx.overridden, contains('reader_scale_mode'));
  });

  test('another title keeps its own scale mode', () async {
    SharedPreferences.setMockInitialValues({
      'manga-1_reader_scale_mode': kScaleFitWidth,
      'manga-2_reader_scale_mode': kScaleKeepAtStart,
    });

    final first = await resolveReaderContext('manga-1');
    final second = await resolveReaderContext('manga-2');

    expect(first.settings.scaleMode, kScaleFitWidth);
    expect(second.settings.scaleMode, kScaleKeepAtStart);
  });

  test('a scale-only override still resolves', () async {
    SharedPreferences.setMockInitialValues({
      'manga-1_reader_scale_mode': kScaleFitCenter,
    });

    final ctx = await resolveReaderContext('manga-1');

    expect(ctx.settings.scaleMode, kScaleFitCenter);
    expect(ctx.overridden, {'reader_scale_mode'});
  });
}
