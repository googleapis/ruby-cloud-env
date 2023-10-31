# Copyright 2017 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "helper"
require "google/cloud/env"


describe Google::Cloud::Env do
  let(:instance_name) { "instance-a1b2" }
  let(:instance_description) { "" }
  let(:instance_zone) { "us-west99-z" }
  let(:instance_machine_type) { "z9999-really-really-huge" }
  let(:instance_tags) { ["erlang", "elixir"] }
  let(:project_id) { "my-project-123" }
  let(:numeric_project_id) { 1234567890 }
  let(:gae_service) { "default" }
  let(:gae_version) { "20170214t123456" }
  let(:gae_memory_mb) { 640 }
  let(:gke_cluster) { "my-cluster" }
  let(:gke_namespace) { "my-namespace" }
  let(:gae_standard_runtime) { "ruby25" }

  let :knative_variables do
    {
      "K_SERVICE" => gae_service,
      "K_REVISION" => gae_version
    }
  end
  let :gae_flex_variables do
    {
      "GAE_INSTANCE" => instance_name,
      "GCLOUD_PROJECT" => project_id,
      "GAE_SERVICE" => gae_service,
      "GAE_VERSION" => gae_version,
      "GAE_MEMORY_MB" => gae_memory_mb
    }
  end
  let :gae_standard_variables do
    {
      "GAE_INSTANCE" => instance_name,
      "GOOGLE_CLOUD_PROJECT" => project_id,
      "GAE_SERVICE" => gae_service,
      "GAE_VERSION" => gae_version,
      "GAE_ENV" => "standard",
      "GAE_RUNTIME" => gae_standard_runtime,
      "GAE_MEMORY_MB" => gae_memory_mb
    }
  end
  let :gke_variables do
    {
      "GKE_NAMESPACE_ID" => gke_namespace
    }
  end
  let :cloud_shell_variables do
    {
      "DEVSHELL_PROJECT_ID" => project_id,
      "DEVSHELL_GCLOUD_CONFIG" => "cloudshell-1234"
    }
  end
  let(:gce_variables) { {} }
  let(:ext_variables) { {} }
  let(:empty_metadata_overrides) { Google::Cloud::Env::ComputeMetadata::Overrides.new }
  let(:gce_metadata_overrides) do
    overrides = empty_metadata_overrides.dup
    overrides.add_ping
    overrides.add "project/project-id", project_id
    overrides.add "project/numeric-project-id", numeric_project_id.to_s
    overrides.add "instance/name", instance_name
    overrides.add "instance/zone", "/project/#{project_id}/zone/#{instance_zone}"
    overrides.add "instance/description", instance_description
    overrides.add "instance/machine-type", "/project/#{project_id}/zone/#{instance_machine_type}"
    overrides.add "instance/tags", JSON.dump(instance_tags)
  end
  let(:gke_metadata_overrides) do
    overrides = gce_metadata_overrides.dup
    overrides.add "instance/attributes/cluster-name", gke_cluster
  end
  let(:env) { Google::Cloud::Env.new }

  def gce_stubs failure_count: 0
    ::Faraday::Adapter::Test::Stubs.new do |stub|
      failure_count.times do
        stub.get("") { |env| raise ::Errno::EHOSTDOWN }
      end
      stub.get("") { |env| [200, {"Metadata-Flavor" => "Google"}, ""] }
      stub.get("/computeMetadata/v1/project/project-id") { |env|
        [200, {}, project_id]
      }
      stub.get("/computeMetadata/v1/project/numeric-project-id") { |env|
        [200, {}, numeric_project_id.to_s]
      }
      stub.get("/computeMetadata/v1/instance/name") { |env|
        [200, {}, instance_name]
      }
      stub.get("/computeMetadata/v1/instance/zone") { |env|
        [200, {}, "/project/#{project_id}/zone/#{instance_zone}"]
      }
      stub.get("/computeMetadata/v1/instance/description") { |env|
        [200, {}, instance_description]
      }
      stub.get("/computeMetadata/v1/instance/machine-type") { |env|
        [200, {}, "/project/#{project_id}/zone/#{instance_machine_type}"]
      }
      stub.get("/computeMetadata/v1/instance/tags") { |env|
        [200, {}, JSON.dump(instance_tags)]
      }
    end
  end

  def gce_conn failure_count: 0
    Faraday::Connection.new do |builder|
      builder.adapter :test, gce_stubs(failure_count: failure_count) do |stub|
        stub.get(//) { |env| [404, {}, "not found"] }
      end
    end
  end

  def gke_conn failure_count: 0
    Faraday::Connection.new do |builder|
      builder.adapter :test, gce_stubs(failure_count: failure_count) do |stub|
        stub.get("/computeMetadata/v1/instance/attributes/cluster-name") { |env|
          [200, {}, gke_cluster]
        }
        stub.get(//) { |env| [404, {}, "not found"] }
      end
    end
  end

  def ext_conn failure_count: 0
    Faraday::Connection.new do |builder|
      builder.adapter :test do |stub|
        stub.get(//) { |env| raise ::Errno::EHOSTDOWN }
      end
    end
  end

  it "returns correct values when running on cloud run" do
    env.variables.backing_data = knative_variables
    env.compute_smbios.override_product_name = "Google"
    env.compute_metadata.overrides = gce_metadata_overrides

    _(env.knative?).must_equal true
    _(env.app_engine?).must_equal false
    _(env.app_engine_flexible?).must_equal false
    _(env.app_engine_standard?).must_equal false
    _(env.kubernetes_engine?).must_equal false
    _(env.cloud_shell?).must_equal false
    _(env.compute_engine?).must_equal true
    _(env.raw_compute_engine?).must_equal false

    _(env.project_id).must_equal project_id
    _(env.numeric_project_id).must_equal numeric_project_id
    _(env.instance_name).must_equal instance_name
    _(env.instance_description).must_equal instance_description
    _(env.instance_machine_type).must_equal instance_machine_type
    _(env.instance_tags).must_equal instance_tags

    _(env.app_engine_service_id).must_be_nil
    _(env.app_engine_service_version).must_be_nil
    _(env.app_engine_memory_mb).must_be_nil

    _(env.kubernetes_engine_cluster_name).must_be_nil
    _(env.kubernetes_engine_namespace_id).must_be_nil
  end

  it "returns correct values when running on app engine flex" do
    env.variables.backing_data = gae_flex_variables
    env.compute_smbios.override_product_name = "Google"
    env.compute_metadata.overrides = gce_metadata_overrides

    _(env.knative?).must_equal false
    _(env.app_engine?).must_equal true
    _(env.app_engine_flexible?).must_equal true
    _(env.app_engine_standard?).must_equal false
    _(env.kubernetes_engine?).must_equal false
    _(env.cloud_shell?).must_equal false
    _(env.compute_engine?).must_equal true
    _(env.raw_compute_engine?).must_equal false

    _(env.project_id).must_equal project_id
    _(env.numeric_project_id).must_equal numeric_project_id
    _(env.instance_name).must_equal instance_name
    _(env.instance_description).must_equal instance_description
    _(env.instance_machine_type).must_equal instance_machine_type
    _(env.instance_tags).must_equal instance_tags

    _(env.app_engine_service_id).must_equal gae_service
    _(env.app_engine_service_version).must_equal gae_version
    _(env.app_engine_memory_mb).must_equal gae_memory_mb

    _(env.kubernetes_engine_cluster_name).must_be_nil
    _(env.kubernetes_engine_namespace_id).must_be_nil
  end

  it "returns correct values when running on app engine standard" do
    env.variables.backing_data = gae_standard_variables
    env.compute_smbios.override_product_name = "Google"
    env.compute_metadata.overrides = gce_metadata_overrides

    _(env.knative?).must_equal false
    _(env.app_engine?).must_equal true
    _(env.app_engine_flexible?).must_equal false
    _(env.app_engine_standard?).must_equal true
    _(env.kubernetes_engine?).must_equal false
    _(env.cloud_shell?).must_equal false
    _(env.compute_engine?).must_equal true
    _(env.raw_compute_engine?).must_equal false

    _(env.project_id).must_equal project_id
    _(env.numeric_project_id).must_equal numeric_project_id
    _(env.instance_name).must_equal instance_name
    _(env.instance_description).must_equal instance_description
    _(env.instance_machine_type).must_equal instance_machine_type
    _(env.instance_tags).must_equal instance_tags

    _(env.app_engine_service_id).must_equal gae_service
    _(env.app_engine_service_version).must_equal gae_version
    _(env.app_engine_memory_mb).must_equal gae_memory_mb

    _(env.kubernetes_engine_cluster_name).must_be_nil
    _(env.kubernetes_engine_namespace_id).must_be_nil
  end

  it "returns correct values when running on kubernetes engine" do
    env.variables.backing_data = gke_variables
    env.compute_smbios.override_product_name = "Google"
    env.compute_metadata.overrides = gke_metadata_overrides

    _(env.knative?).must_equal false
    _(env.app_engine?).must_equal false
    _(env.app_engine_flexible?).must_equal false
    _(env.app_engine_standard?).must_equal false
    _(env.kubernetes_engine?).must_equal true
    _(env.cloud_shell?).must_equal false
    _(env.compute_engine?).must_equal true
    _(env.raw_compute_engine?).must_equal false

    _(env.project_id).must_equal project_id
    _(env.numeric_project_id).must_equal numeric_project_id
    _(env.instance_name).must_equal instance_name
    _(env.instance_description).must_equal instance_description
    _(env.instance_machine_type).must_equal instance_machine_type
    _(env.instance_tags).must_equal instance_tags

    _(env.app_engine_service_id).must_be_nil
    _(env.app_engine_service_version).must_be_nil
    _(env.app_engine_memory_mb).must_be_nil

    _(env.kubernetes_engine_cluster_name).must_equal gke_cluster
    _(env.kubernetes_engine_namespace_id).must_equal gke_namespace
  end

  it "returns correct values when running on cloud shell" do
    env.variables.backing_data = cloud_shell_variables
    env.compute_smbios.override_product_name = "Google"
    env.compute_metadata.overrides = gce_metadata_overrides

    _(env.knative?).must_equal false
    _(env.app_engine?).must_equal false
    _(env.app_engine_flexible?).must_equal false
    _(env.app_engine_standard?).must_equal false
    _(env.kubernetes_engine?).must_equal false
    _(env.cloud_shell?).must_equal true
    _(env.compute_engine?).must_equal true
    _(env.raw_compute_engine?).must_equal false

    _(env.project_id).must_equal project_id
    _(env.numeric_project_id).must_be_nil
    _(env.instance_name).must_equal instance_name
    _(env.instance_description).must_equal instance_description
    _(env.instance_machine_type).must_equal instance_machine_type
    _(env.instance_tags).must_equal instance_tags

    _(env.app_engine_service_id).must_be_nil
    _(env.app_engine_service_version).must_be_nil
    _(env.app_engine_memory_mb).must_be_nil

    _(env.kubernetes_engine_cluster_name).must_be_nil
    _(env.kubernetes_engine_namespace_id).must_be_nil
  end

  it "returns correct values when running on compute engine" do
    env.variables.backing_data = gce_variables
    env.compute_smbios.override_product_name = "Google"
    env.compute_metadata.overrides = gce_metadata_overrides

    _(env.knative?).must_equal false
    _(env.app_engine?).must_equal false
    _(env.app_engine_flexible?).must_equal false
    _(env.app_engine_standard?).must_equal false
    _(env.kubernetes_engine?).must_equal false
    _(env.cloud_shell?).must_equal false
    _(env.compute_engine?).must_equal true
    _(env.raw_compute_engine?).must_equal true

    _(env.project_id).must_equal project_id
    _(env.numeric_project_id).must_equal numeric_project_id
    _(env.instance_name).must_equal instance_name
    _(env.instance_description).must_equal instance_description
    _(env.instance_machine_type).must_equal instance_machine_type
    _(env.instance_tags).must_equal instance_tags

    _(env.app_engine_service_id).must_be_nil
    _(env.app_engine_service_version).must_be_nil
    _(env.app_engine_memory_mb).must_be_nil

    _(env.kubernetes_engine_cluster_name).must_be_nil
    _(env.kubernetes_engine_namespace_id).must_be_nil
  end

  it "returns correct values when not running on gcp" do
    env.variables.backing_data = ext_variables
    env.compute_smbios.override_product_name = "Someone Else"
    env.compute_metadata.overrides = empty_metadata_overrides

    _(env.knative?).must_equal false
    _(env.app_engine?).must_equal false
    _(env.app_engine_flexible?).must_equal false
    _(env.app_engine_standard?).must_equal false
    _(env.kubernetes_engine?).must_equal false
    _(env.cloud_shell?).must_equal false
    _(env.compute_engine?).must_equal false
    _(env.raw_compute_engine?).must_equal false

    _(env.project_id).must_be_nil
    _(env.numeric_project_id).must_be_nil
    _(env.instance_name).must_be_nil
    _(env.instance_description).must_be_nil
    _(env.instance_machine_type).must_be_nil
    _(env.instance_tags).must_be_nil

    _(env.app_engine_service_id).must_be_nil
    _(env.app_engine_service_version).must_be_nil
    _(env.app_engine_memory_mb).must_be_nil

    _(env.kubernetes_engine_cluster_name).must_be_nil
    _(env.kubernetes_engine_namespace_id).must_be_nil
  end
end
