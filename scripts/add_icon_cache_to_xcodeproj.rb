#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/tyeerth/Documents/MAC_software/SnapClick/SnapClick.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到 Shared group
shared_group = project.main_group['Shared']
raise "Shared group not found" unless shared_group

# 找到两个 target
main_target    = project.targets.find { |t| t.name == 'SnapClick' }
finder_target  = project.targets.find { |t| t.name == 'FinderExtension' }
raise "Targets not found" unless main_target && finder_target

icon_path = 'Shared/IconCache.swift'

# 检查是否已存在
existing = shared_group.files.find { |f| f.path == 'IconCache.swift' }
if existing
  puts "IconCache.swift already in group"
  file_ref = existing
else
  file_ref = shared_group.new_file('IconCache.swift')
  puts "Added file reference to Shared group"
end

# 添加到两个 target
[main_target, finder_target].each do |target|
  already = target.source_build_phase.files_references.include?(file_ref)
  unless already
    target.add_file_references([file_ref])
    puts "Added to target: #{target.name}"
  else
    puts "Already in target: #{target.name}"
  end
end

project.save
puts "Saved."
