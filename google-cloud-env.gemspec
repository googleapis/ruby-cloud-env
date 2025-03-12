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

  gem.required_ruby_version = ">= 3.0"

  gem.add_dependency "base64", "~> 0.2"
  gem.add_dependency "faraday", ">= 1.0", "< 3.a"

  if gem.respond_to? :metadata
    gem.metadata["changelog_uri"] = "https://rubydoc.info/gems/google-cloud-env/#{gem_version}/CHANGELOG.md"
    gem.metadata["source_code_uri"] = "https://github.com/googleapis/ruby-cloud-env"
    gem.metadata["bug_tracker_uri"] = "https://github.com/googleapis/ruby-cloud-env/issues"
    gem.metadata["documentation_uri"] = "https://rubydoc.info/gems/google-cloud-env/#{gem_version}"
  end
end
