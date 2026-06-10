#!/usr/bin/env ruby
# Trägt Shared/BlockRuleStore.swift in den Shared-Group ein und kompiliert es in
# alle drei Targets (App + beide Extensions). Idempotent.
require 'xcodeproj'

project = Xcodeproj::Project.open('AntiDoom.xcodeproj')
group = project.main_group.find_subpath('Shared', true)
group.set_path('Shared')

name = 'BlockRuleStore.swift'
ref = group.files.find { |f| f.display_name == name } || group.new_reference(name)

%w[AntiDoom DeviceActivityMonitor ShieldConfiguration].each do |target_name|
  target = project.targets.find { |t| t.name == target_name } or abort "#{target_name} not found"
  already = target.source_build_phase.files.any? { |bf| bf.file_ref == ref }
  target.add_file_references([ref]) unless already
end

project.save
puts "Added #{name} to all three targets."
