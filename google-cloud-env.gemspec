require File.expand_path("lib/google/cloud/env/version", __dir__)
gem_version = Google::Cloud::Env::VERSION

Gem::Specification.new do |gem|
  gem.name          = "google-cloud-env"
  gem.version       = gem_version

  gem.authors       = ["Daniel Azuma"]
  gem.email         = ["dazuma@google.com"]
  gem.description   = "google-cloud-env provides information on the Google Cloud Platform hosting environment. " \
                        "Applications can use this library to determine hosting context information such as the " \
                        "project ID, whether App Engine is running, what tags are set on the VM instance, and much " \
                        "more."
  gem.summary       = "Google Cloud Platform hosting environment information."
  gem.homepage      = "https://github.com/googleapis/ruby-cloud-env"
  gem.license       = "Apache-2.0"

  gem.files         = Dir.glob("lib/**/*.rb") + Dir.glob("*.md") + ["LICENSE", ".yardopts"]
  gem.require_paths = ["lib"]

  gem.required_ruby_version = ">= 2.5"

  gem.add_dependency "faraday", ">= 0.17.3", "< 2.0"

  gem.add_development_dependency "autotest-suffix", "~> 1.1"
  gem.add_development_dependency "google-style", "~> 1.25.1"
  gem.add_development_dependency "minitest", "~> 5.10"
  gem.add_development_dependency "minitest-autotest", "~> 1.0"
  gem.add_development_dependency "minitest-focus", "~> 1.1"
  gem.add_development_dependency "minitest-rg", "~> 5.2"
  gem.add_development_dependency "redcarpet", "~> 3.0"
  gem.add_development_dependency "simplecov", "~> 0.9"
  gem.add_development_dependency "yard", "~> 0.9"
  gem.add_development_dependency "yard-doctest", "~> 0.1.13"

  if gem.respond_to? :metadata
    gem.metadata["changelog_uri"] = "https://googleapis.dev/ruby/google-cloud-env/v#{gem_version}/file.CHANGELOG.html"
    gem.metadata["source_code_uri"] = "https://github.com/googleapis/ruby-cloud-env"
    gem.metadata["bug_tracker_uri"] = "https://github.com/googleapis/ruby-cloud-env/issues"
    gem.metadata["documentation_uri"] = "https://googleapis.dev/ruby/google-cloud-env/v#{gem_version}"
  end
end
