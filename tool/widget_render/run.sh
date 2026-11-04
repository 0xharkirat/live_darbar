#!/bin/sh
# Draws the iPhone widget, idle, in English and Punjabi, into assets/images/.
# Needs a Mac with Xcode. See docs/DESIGN.md, "Home screen widget".
#
#     tool/widget_render/run.sh
set -eu
root="$(cd "$(dirname "$0")/../.." && pwd)"
build="${TMPDIR:-/tmp}/live_darbar_widget_render"
mkdir -p "$build"

# The widget view and its store, compiled for the Mac. The view needs the
# intents' types (WidgetPlaySource and the 2 button intents), and compiles
# them without LIVE_DARBAR_APP, as the widget extension does.
taskpolicy -b swiftc -parse-as-library -O \
  -o "$build/render" \
  "$root/tool/widget_render/render.swift" \
  "$root/ios/LiveDarbarWidget/LiveDarbarWidgetView.swift" \
  "$root/ios/LiveDarbarWidget/WidgetStore.swift" \
  "$root/ios/Runner/WidgetPlayIntents.swift"

"$build/render" "$root/assets/fonts/TiroGurmukhi-400.ttf" "$root/assets/images"
