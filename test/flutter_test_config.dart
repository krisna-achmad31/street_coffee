import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget tests run offline: never let google_fonts reach the network.
///
/// The default test font draws every glyph as a full square, so text is far
/// wider than on a phone and overflow checks would cry wolf. Fonts of similar
/// width are loaded under the names google_fonts asks for ("Inter_600",
/// "SpaceMono_700", …): Roboto from the Flutter SDK for Inter and Syne, and a
/// system monospace font (≈0.6 em, like Space Mono) when one is installed.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final roboto = _sdkRoboto();
  final mono = _systemMono() ?? roboto;
  await _loadAs(['Inter', 'Syne'], roboto);
  await _loadAs(['SpaceMono'], mono);
  await testMain();
}

const _weights = ['regular', '100', '200', '300', '500', '600', '700', '800', '900'];

Future<void> _loadAs(List<String> families, List<ByteData> fonts) async {
  if (fonts.isEmpty) return;
  for (final family in families) {
    for (final w in _weights) {
      for (final variant in [w, w == 'regular' ? 'italic' : '${w}italic']) {
        final loader = FontLoader('${family}_$variant');
        for (final f in fonts) {
          loader.addFont(Future.value(f));
        }
        await loader.load();
      }
    }
  }
}

List<ByteData> _read(Iterable<File> files) =>
    [for (final f in files) ByteData.sublistView(f.readAsBytesSync())];

/// flutter_tester lives under `<sdk>/bin/cache/artifacts/engine/…`.
List<ByteData> _sdkRoboto() {
  for (var d = File(Platform.resolvedExecutable).parent;
      d.path != d.parent.path;
      d = d.parent) {
    final dir = Directory('${d.path}/bin/cache/artifacts/material_fonts');
    if (dir.existsSync()) {
      return _read(dir.listSync().whereType<File>().where((f) =>
          RegExp(r'Roboto-(Light|Regular|Medium|Bold|Black)\.ttf$')
              .hasMatch(f.path)));
    }
  }
  return const [];
}

List<ByteData>? _systemMono() {
  for (final group in const [
    ['liberation/LiberationMono-Regular.ttf', 'liberation/LiberationMono-Bold.ttf'],
    ['dejavu/DejaVuSansMono.ttf', 'dejavu/DejaVuSansMono-Bold.ttf'],
  ]) {
    final files = [for (final p in group) File('/usr/share/fonts/truetype/$p')];
    if (files.every((f) => f.existsSync())) return _read(files);
  }
  return null;
}
