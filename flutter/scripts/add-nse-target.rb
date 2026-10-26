#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the Notification Service Extension target SallaPushNotificationService to a Flutter app's ios/Runner.xcodeproj,
# as the README's steps do in Xcode, for an app whose extension links SallaPushExtension through CocoaPods: no Swift
# package reference. The extension's NotificationService.swift and Info.plist come from <source folder>; it gets the
# app's version from the app's pubspec.yaml, as Runner does through Generated.xcconfig; and it is embedded in Runner
# before Runner's "Thin Binary" phase. scripts/verify.sh ios-pods runs it on a fresh app, with the xcodeproj gem that
# CocoaPods ships.
#
#   ruby scripts/add-nse-target.rb <app>/ios <source folder>

require 'fileutils'
require 'xcodeproj'

NAME = 'SallaPushNotificationService'

ios, source = ARGV
unless ARGV.length == 2 && File.directory?(File.join(ios.to_s, 'Runner.xcodeproj')) &&
       %w[NotificationService.swift Info.plist].all? { |file| File.file?(File.join(source.to_s, file)) }
  abort 'usage: ruby scripts/add-nse-target.rb <app>/ios <folder with NotificationService.swift and Info.plist>'
end

version = File.foreach(File.join(ios, '..', 'pubspec.yaml')).map { |line| line[/^version: (\S+)$/, 1] }.compact.first
abort "add-nse-target.rb: #{File.join(ios, '..', 'pubspec.yaml')} has no version" unless version
build_name, build_number = version.split('+', 2)

project = Xcodeproj::Project.open(File.join(ios, 'Runner.xcodeproj'))
runner = project.targets.find { |target| target.name == 'Runner' }
abort 'add-nse-target.rb: the project has no Runner target' unless runner
abort "add-nse-target.rb: the project already has a #{NAME} target" if project.targets.any? { |target| target.name == NAME }

FileUtils.mkdir_p(File.join(ios, NAME))
%w[NotificationService.swift Info.plist].each { |file| FileUtils.cp(File.join(source, file), File.join(ios, NAME)) }

deployment = (project.build_configurations + runner.build_configurations)
             .map { |configuration| configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] }.compact.first
extension = project.new_target(:app_extension, NAME, :ios, deployment, nil, :swift)
group = project.main_group.new_group(NAME, NAME)
extension.add_file_references([group.new_reference('NotificationService.swift')])
group.new_reference('Info.plist')

extension.build_configurations.each do |configuration|
  app_id = runner.build_configuration_list[configuration.name]&.build_settings&.fetch('PRODUCT_BUNDLE_IDENTIFIER', nil)
  abort "add-nse-target.rb: Runner has no bundle id in #{configuration.name}" unless app_id
  configuration.build_settings.merge!(
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'FLUTTER_BUILD_NAME' => build_name,
    'FLUTTER_BUILD_NUMBER' => build_number || '1',
    'INFOPLIST_FILE' => "#{NAME}/Info.plist",
    'PRODUCT_BUNDLE_IDENTIFIER' => "#{app_id}.#{NAME}",
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SKIP_INSTALL' => 'YES',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2'
  )
end

embed = runner.copy_files_build_phases.find { |phase| phase.symbol_dst_subfolder_spec == :plug_ins } ||
        runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(extension.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
# Embedding after "Thin Binary", a script phase, makes Xcode report a dependency cycle.
thin_binary = runner.build_phases.index { |phase| phase.display_name == 'Thin Binary' }
runner.build_phases.move(embed, thin_binary) if thin_binary && runner.build_phases.index(embed) > thin_binary
runner.add_dependency(extension)
project.save
puts "added #{NAME} (#{build_name}, #{build_number || '1'}) to #{File.join(ios, 'Runner.xcodeproj')}"
