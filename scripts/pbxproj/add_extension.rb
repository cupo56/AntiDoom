#!/usr/bin/env ruby
# Adds an iOS app-extension target to AntiDoom.xcodeproj, wires its Info.plist /
# entitlements / Swift source, adds the Shared/* sources to it, makes the app
# depend on it, and embeds the .appex into the app's PlugIns folder.
#
# Usage:
#   ruby scripts/pbxproj/add_extension.rb <TargetName> <BundleID> <PrincipalClass>
#
# Idempotent: re-running for an existing target is a no-op.
require 'xcodeproj'

target_name, bundle_id, principal = ARGV
unless target_name && bundle_id && principal
  abort 'usage: add_extension.rb <TargetName> <BundleID> <PrincipalClass>'
end

TEAM = '7PPXXRWMCT'
DEPLOYMENT = '26.5'

project = Xcodeproj::Project.open('AntiDoom.xcodeproj')

if project.targets.any? { |t| t.name == target_name }
  puts "Target #{target_name} already exists — skipping."
  exit 0
end

app = project.targets.find { |t| t.name == 'AntiDoom' } or abort 'AntiDoom target not found'

ext = project.new_target(:app_extension, target_name, :ios, DEPLOYMENT)

ext.build_configurations.each do |c|
  bs = c.build_settings
  bs['PRODUCT_NAME'] = '$(TARGET_NAME)'
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  bs['INFOPLIST_FILE'] = "#{target_name}/Info.plist"
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['CODE_SIGN_ENTITLEMENTS'] = "#{target_name}/#{target_name}.entitlements"
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = TEAM
  bs['SWIFT_VERSION'] = '5.0'
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['SKIP_INSTALL'] = 'YES'
  bs['CURRENT_PROJECT_VERSION'] = '1'
  bs['MARKETING_VERSION'] = '1.0'
  bs['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../../Frameworks']
end

# File group for the extension's own files (path = folder of the same name).
group = project.main_group.find_subpath(target_name, true)
group.set_path(target_name)
swift_ref = group.new_reference("#{principal}.swift")
ext.add_file_references([swift_ref])
group.new_reference('Info.plist')
group.new_reference("#{target_name}.entitlements")

# Compile the Shared/* sources into the extension too.
shared_group = project.main_group.find_subpath('Shared') or abort 'Shared group not found (run 02_add_shared.rb first)'
shared_swift = shared_group.files.select { |f| f.display_name.end_with?('.swift') }
ext.add_file_references(shared_swift)

# App depends on the extension and embeds it.
app.add_dependency(ext)
embed = app.copy_files_build_phases.find { |p| p.display_name == 'Embed Foundation Extensions' }
unless embed
  embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  embed.dst_path = ''
end
build_file = embed.add_file_reference(ext.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts "Added extension target #{target_name} and embedded it in AntiDoom."
