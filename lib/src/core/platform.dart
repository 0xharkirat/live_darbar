import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app runs in a browser, behind a provider so a test can say so.
///
/// `kIsWeb` is a compile-time constant, so a widget test cannot flip it. A
/// screen that differs on the web reads this instead, with
/// `ref.watch(isWebProvider)`.
final isWebProvider = Provider<bool>((ref) => kIsWeb || kIsWasm);
