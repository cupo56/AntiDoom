#!/usr/bin/env ruby
# Wired die TP3-Shared-Dateien in die bestehenden Targets:
#   ReflectionStore.swift      -> AntiDoom, DeviceActivityMonitor, ShieldConfiguration
#   DeviceActivityManager.swift -> AntiDoom, DeviceActivityMonitor
#     (NICHT ShieldConfiguration — die rendert nur, braucht kein DeviceActivity)
# Idempotent. ShieldAction bekommt beide später automatisch via add_extension.rb.
require 'xcodeproj'

project = Xcodeproj::Project.open('AntiDoom.xcodeproj')
group = project.main_group.find_subpath('Shared', true)
group.set_path('Shared')

add = lambda do |name, target_names|
  ref = group.files.find { |f| f.display_name == name } || group.new_reference(name)
  target_names.each do |tn|
    t = project.targets.find { |x| x.name == tn } or abort "#{tn} not found"
    already = t.source_build_phase.files.any? { |bf| bf.file_ref == ref }
    t.add_file_references([ref]) unless already
  end
end

add.call('ReflectionStore.swift', %w[AntiDoom DeviceActivityMonitor ShieldConfiguration])
add.call('DeviceActivityManager.swift', %w[AntiDoom DeviceActivityMonitor])

project.save
puts 'Wired TP3 shared sources into existing targets.'
