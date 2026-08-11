/// Kept in step with `pubspec.yaml` by hand, which is a trap.
///
/// package_info_plus is now a dependency, added for the update check, and it
/// reads the real installed version from the platform bundle. The About screen
/// should use that instead so this cannot drift again. See the About rewrite.
const appVersion = "2.1.0+7";
