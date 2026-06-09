#!/usr/bin/env ruby
# Creates a plain (non-synchronized) `Shared` group with explicit file references
# and adds the shared Swift sources to the AntiDoom app target's compile phase.
# Extension targets pick these same references up later via add_extension.rb.
require 'xcodeproj'

project = Xcodeproj::Project.open('AntiDoom.xcodeproj')
app = project.targets.find { |t| t.name == 'AntiDoom' } or abort 'AntiDoom target not found'

group = project.main_group.find_subpath('Shared', true)
group.set_path('Shared')

%w[SharedStore.swift FoundationProbe.swift].each do |name|
  next if group.files.any? { |f| f.display_name == name }
  ref = group.new_reference(name)
  app.add_file_references([ref])
end

project.save
puts 'Added Shared group and sources to AntiDoom target.'
