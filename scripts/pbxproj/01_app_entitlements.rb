#!/usr/bin/env ruby
# Sets CODE_SIGN_ENTITLEMENTS on the AntiDoom app target for both configs.
require 'xcodeproj'

project = Xcodeproj::Project.open('AntiDoom.xcodeproj')
app = project.targets.find { |t| t.name == 'AntiDoom' } or abort 'AntiDoom target not found'

app.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'AntiDoom/AntiDoom.entitlements'
end

project.save
puts 'Set CODE_SIGN_ENTITLEMENTS on AntiDoom.'
