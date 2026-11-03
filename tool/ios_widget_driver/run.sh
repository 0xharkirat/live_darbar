#!/bin/zsh
# Presses the real iPhone widget on a booted simulator, with no human.
#
#   tool/ios_widget_driver/run.sh add               put the widget on the home screen
#   tool/ios_widget_driver/run.sh tap "live kirtan"  tap a widget button
#   tool/ios_widget_driver/run.sh tap hukamnama
#   tool/ios_widget_driver/run.sh quick-action       long press the icon, then Live Kirtan
#
# Build and install the app first, signed ad hoc so the App Group works:
#   flutter build ios --simulator --debug
#   xcrun simctl install booted build/ios/iphonesimulator/Runner.app
# A build with --no-codesign has no entitlements. The simulator then gives the
# app and the widget separate stores, and the widget never sees the app's state.
#
# Then read the result: the screenshots and trees are in /tmp/live_darbar_widget_driver,
# and the widget's state is `ld_playback` in the App Group's plist:
#   xcrun simctl get_app_container booted com.hsiharki.liveDarbar groups
#
# SIM is the simulator's UDID. It defaults to the booted one. Each run is a
# heavy command: it runs on the efficiency cores, and 1 at a time.
set -e
here=${0:A:h}
sim=${SIM:-$(xcrun simctl list devices booted | grep -Eo '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | head -1)}
[[ -n $sim ]] || { echo "No booted simulator."; exit 1; }
mkdir -p /tmp/live_darbar_widget_driver

case $1 in
  add) only=testAddWidget ;;
  tap) only=testTapTarget; echo "${2:-live kirtan}" > /tmp/live_darbar_widget_driver/target.txt ;;
  quick-action) only=testQuickAction ;;
  *) echo "usage: run.sh add | tap <words> | quick-action"; exit 1 ;;
esac

cd $here
[[ -d Driver.xcodeproj ]] || GEM_HOME=$(ls -d /opt/homebrew/Cellar/cocoapods/*/libexec | tail -1) /opt/homebrew/opt/ruby/bin/ruby gen.rb
taskpolicy -b xcodebuild test -project Driver.xcodeproj -scheme Driver \
  -destination "id=$sim" -derivedDataPath .dd \
  -only-testing:DriverUITests/SpringBoardTests/$only 2>&1 \
  | grep -E 'error:|passed|failed|TEST'
