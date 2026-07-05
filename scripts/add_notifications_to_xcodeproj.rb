#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/tyeerth/Documents/MAC_software/SnapClick/SnapClick.xcodeproj'
project = Xcodeproj::Project.open(project_path)

shared_group = project.main_group['Shared']
raise "Shared group not found" unless shared_group

main_target    = project.targets.find { |t| t.name == 'SnapClick' }
finder_target  = project.targets.find { |t| t.name == 'FinderExtension' }
raise "Targets not found" unless main_target && finder_target

file_ref = shared_group.files.find { |f| f.path == 'Notifications.swift' }
unless file_ref
  file_ref = shared_group.new_file('Notifications.swift')
  puts "Added Notifications.swift file ref"
end

[main_target, finder_target].each do |target|
  unless target.source_build_phase.files_references.include?(file_ref)
    target.add_file_references([file_ref])
    puts "Added Notifications.swift to target: #{target.name}"
  end
end

project.save
puts "Saved."
