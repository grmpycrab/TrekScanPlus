import 'package:flutter/foundation.dart';

/// Drives the startup loading-screen progress text.
///
/// A thin [ValueNotifier<String>] wrapper that exposes named stage constants
/// so the boot sequence and the [StartupView] text label stay in sync without
/// scattering magic strings across files.
///
/// Performance contract:
/// Only the [ValueListenableBuilder] node inside [StartupView] rebuilds when
/// [value] changes — the surrounding Scaffold, logo, and
/// [LinearProgressIndicator] are completely static subtrees and are never
/// invalidated by stage updates.
class StartupProgressNotifier extends ValueNotifier<String> {
  StartupProgressNotifier() : super('');

  // Stage message constants
  static const stage1 = 'Initializing security frameworks…';
  static const stage2 = 'Charting mountain trail coordinates…';
  static const stage3 = 'Synchronizing offline progress…';
  static const stage4 = 'Caching personal achievements…';
  static const stageError = 'Initialization error. Retrying…';
}
