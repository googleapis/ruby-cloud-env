require "bundler/setup"
require "bundler/gem_tasks"

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "rake/testtask"
desc "Run tests."
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

namespace :test do
  desc "Run tests with coverage."
  task :coverage do
    require "simplecov"
    SimpleCov.start do
      command_name "google-cloud-env"
      track_files "lib/**/*.rb"
      add_filter "test/"
    end

    Rake::Task[:test].invoke
  end
end

desc "Run acceptance tests."
task :acceptance do
  puts "The google-cloud-env gem does not have acceptance tests."
end

namespace :acceptance do
  task :run do
    puts "This gem does not have acceptance tests."
  end
  desc "Run acceptance cleanup."
  task :cleanup do
    # Do nothing
  end
end

desc "Run yard-doctest example tests."
task :doctest do
  puts "The google-cloud-env gem does not have doctest tests."
end

desc "Start an interactive shell."
task :console do
  require "irb"
  require "irb/completion"
  require "pp"

  $LOAD_PATH.unshift "lib"

  require "google-cloud-env"

  ARGV.clear
  IRB.start
end

require "yard"
require "yard/rake/yardoc_task"
YARD::Rake::YardocTask.new do |y|
  y.options << "--fail-on-warning"
end

desc "Run the CI build"
task :ci do
  header "BUILDING google-cloud-env"
  header "google-cloud-env rubocop", "*"
  Rake::Task[:rubocop].invoke
  header "google-cloud-env yard", "*"
  Rake::Task[:yard].invoke
  header "google-cloud-env doctest", "*"
  Rake::Task[:doctest].invoke
  header "google-cloud-env test", "*"
  Rake::Task[:test].invoke
end
namespace :ci do
  desc "Run the CI build, with acceptance tests."
  task :acceptance do
    Rake::Task[:ci].invoke
    header "google-cloud-env acceptance", "*"
    Rake::Task[:acceptance].invoke
  end
  task :a do
    # This is a handy shortcut to save typing
    Rake::Task["ci:acceptance"].invoke
  end
end

task default: :test

def header str, token = "#"
  line_length = str.length + 8
  puts ""
  puts token * line_length
  puts "#{token * 3} #{str} #{token * 3}"
  puts token * line_length
  puts ""
end
