# frozen_string_literal: true

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "bundler/gem_tasks"
require "open3"
require "rake/clean"
require "rake/testtask"
require "rubocop/rake_task"
require "yard"

# The entries in .gitignore.
CLEAN.include "keyfile.json", "coverage", "doc", "pkg", "html", "node_modules", "package-lock.json",
              "vendor/bundle", "**/.DS_STORE", ".bundle", ".vagrant", ".yardoc",
              "integration/*/vendor", "integration/*/google-cloud-env"

# Minitest 5.19+ defines the legacy `MiniTest` constant only when MT_COMPAT is set.
task :mt_compat do
  ENV["MT_COMPAT"] = "true"
end

Rake::TestTask.new test: :mt_compat do |t|
  t.libs = ["lib", "test"]
  t.test_files = FileList["test/**/*_test.rb"]
end

RuboCop::RakeTask.new

desc "Generate YARD documentation (YARDOC_OUTPUT=false only checks for warnings)"
YARD::Rake::YardocTask.new :yardoc do |t|
  t.options = ["--fail-on-warning"]
  t.options << "--no-output" if ENV["YARDOC_OUTPUT"] == "false"
end

desc "Alias for yardoc, used by the release tooling"
task yard: :yardoc

desc "Check the links in the generated documentation"
task linkinator: :yardoc do
  output, status = Open3.capture2 "npx", "linkinator", "./doc", "--retry-errors",
                                  "--skip", "^https?://(www\\.)?stackoverflow\\.com"
  puts output
  broken = output.lines.select { |line| line =~ /^\[(\d+)\]/ && Regexp.last_match(1) != "200" }
  broken.each { |line| puts line }
  abort "linkinator failed" unless status.success? && broken.empty?
end

namespace :linkinator do
  desc "Install linkinator"
  task :install do
    sh "npm", "install", "linkinator"
  end
end

desc "Run CI checks"
task ci: ["test", "rubocop", "build", "yardoc", "linkinator"]
