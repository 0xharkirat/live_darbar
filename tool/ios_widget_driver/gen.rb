# Writes Driver.xcodeproj: a host app, and a UI test bundle that drives
# SpringBoard. Run it with the xcodeproj gem, as run.sh does.
require 'fileutils'
require 'xcodeproj'

dir = File.dirname(File.expand_path(__FILE__))
path = File.join(dir, 'Driver.xcodeproj')
FileUtils.rm_rf(path)
project = Xcodeproj::Project.new(path)
host = project.new_target(:application, 'Host', :ios, '17.0')
ui = project.new_target(:ui_test_bundle, 'DriverUITests', :ios, '17.0')
host.build_configurations.each do |c|
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'dev.hark.driverhost'
  c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  c.build_settings['SWIFT_VERSION'] = '5.0'
end
ui.build_configurations.each do |c|
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'dev.hark.driveruitests'
  c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  c.build_settings['SWIFT_VERSION'] = '5.0'
  c.build_settings['TEST_TARGET_NAME'] = 'Host'
end
ui.add_dependency(host)
group = project.main_group
host.add_file_references([group.new_file('Host/main.swift')])
Dir[File.join(dir, 'DriverUITests/*.swift')].each do |f|
  ui.add_file_references([group.new_file("DriverUITests/#{File.basename(f)}")])
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(host)
scheme.add_test_target(ui)
scheme.save_as(path, 'Driver', true)
