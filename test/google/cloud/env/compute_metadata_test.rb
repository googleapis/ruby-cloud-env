# frozen_string_literal: true

# Copyright 2023 Google LLC
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
require "google/cloud/env/compute_metadata"

describe Google::Cloud::Env::ComputeMetadata do
  let(:variables) { Google::Cloud::Env::Variables.new }
  let(:compute_smbios) {
    Google::Cloud::Env::ComputeSMBIOS.new.tap{ |cs| cs.override_product_name = "Google" }
  }
  let(:compute_metadata) {
    metadata = Google::Cloud::Env::ComputeMetadata.new variables: variables,
                                                       compute_smbios: compute_smbios
    metadata.retry_interval = 0
    metadata
  }
  let(:project_id) { "my-project" }
  let(:flavor_header) { { "Metadata-Flavor" => "Google" } }

  describe "host" do
    it "uses the default host" do
      assert_equal Google::Cloud::Env::ComputeMetadata::DEFAULT_HOST, compute_metadata.host
    end

    it "sets a host given only a hostname" do
      compute_metadata.host = "metadata.google.internal"
      assert_equal "http://metadata.google.internal", compute_metadata.host
    end

    it "honors GCE_METADATA_HOST" do
      variables.backing_data = { "GCE_METADATA_HOST" => "metadata.google.internal" }
      assert_equal "http://metadata.google.internal", compute_metadata.host
    end
  end

  describe "lookup_response" do
    it "looks up an entry" do
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/project/project-id" do |_env|
          [200, flavor_header, project_id]
        end
      end
      response = compute_metadata.lookup_response "project/project-id"
      assert_equal project_id, response.body
      assert_equal 200, response.status
      assert_in_delta Process.clock_gettime(Process::CLOCK_MONOTONIC), response.retrieval_monotonic_time, 0.1
    end

    it "retries a lookup" do
      failures_left = 2
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/project/project-id" do |_env|
          failures_left -= 1
          raise Faraday::ConnectionFailed unless failures_left.negative?
          [200, flavor_header, project_id]
        end
      end
      response = compute_metadata.lookup_response "project/project-id"
      assert_equal project_id, response.body
      assert_equal 200, response.status
      expected_final_failures_left = -1
      assert_equal expected_final_failures_left, failures_left
    end

    it "runs out of retries" do
      failures_left = 3
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/project/project-id" do |_env|
          failures_left -= 1
          raise Faraday::ConnectionFailed unless failures_left.negative?
          [200, flavor_header, project_id]
        end
      end
      assert_raises Google::Cloud::Env::MetadataServerNotResponding do
        compute_metadata.lookup_response "project/project-id"
      end
    end

    it "caches a lookup" do
      lookup_count = 0
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/project/project-id" do |_env|
          lookup_count += 1
          raise Faraday::ConnectionFailed if lookup_count > 1
          [200, flavor_header, project_id]
        end
      end
      current_time = Process.clock_gettime Process::CLOCK_MONOTONIC
      response1 = compute_metadata.lookup_response "project/project-id"
      assert_equal project_id, response1.body
      assert_equal 200, response1.status
      assert_in_delta current_time, response1.retrieval_monotonic_time, 0.1
      assert_equal 1, lookup_count
      sleep 0.5
      response2 = compute_metadata.lookup_response "project/project-id"
      assert_equal project_id, response2.body
      assert_equal 200, response2.status
      assert_in_delta current_time, response1.retrieval_monotonic_time, 0.1
      assert_equal 1, lookup_count
    end

    it "expires access token values" do
      token = {data: "abcdef", expires_in: 211}
      token_json = JSON.generate token
      count = 0
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/instance/service-accounts/12345/token" do |_env|
          count += 1
          [200, flavor_header, token_json]
        end
      end
      response1 = compute_metadata.lookup_response "instance/service-accounts/12345/token"
      assert_equal token_json, response1.body
      assert_equal 1, count
      response2 = compute_metadata.lookup_response "instance/service-accounts/12345/token"
      assert_equal token_json, response2.body
      assert_equal 1, count
      sleep 1.1
      response3 = compute_metadata.lookup_response "instance/service-accounts/12345/token"
      assert_equal token_json, response3.body
      assert_equal 2, count
      response4 = compute_metadata.lookup_response "instance/service-accounts/12345/token"
      assert_equal token_json, response4.body
      assert_equal 2, count
    end

    it "does not make an http request if SMBIOS check fails" do
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/project/project-id" do |_env|
          raise "Whoa bad"
        end
      end
      compute_smbios.override_product_name = "Someone Else"
      assert_raises Google::Cloud::Env::MetadataServerNotResponding do
        compute_metadata.lookup_response("project/project-id")
      end
      assert_equal :no, compute_metadata.existence_immediate
    end

    describe "existence updates" do
      it "sets existence to confirmed on good result" do
        compute_metadata.connection.adapter :test do |stub|
          stub.get "/computeMetadata/v1/project/project-id" do |_env|
            [200, flavor_header, project_id]
          end
        end
        compute_metadata.lookup_response "project/project-id"
        assert_equal :confirmed, compute_metadata.existence_immediate
      end

      it "sets existence to confirmed on 404" do
        compute_metadata.connection.adapter :test do |stub|
          stub.get "/computeMetadata/v1/project/unknown-key" do |_env|
            [404, flavor_header, ""]
          end
        end
        compute_metadata.lookup_response "project/unknown-key"
        assert_equal :confirmed, compute_metadata.existence_immediate
      end

      it "sets existence to unconfirmed on ConnectionFailed" do
        compute_metadata.connection.adapter :test do |stub|
          stub.get "/computeMetadata/v1/project/project-id" do |_env|
            raise Faraday::ConnectionFailed
          end
        end
        assert_raises Google::Cloud::Env::MetadataServerNotResponding do
          compute_metadata.lookup_response "project/project-id"
        end
        assert_equal :unconfirmed, compute_metadata.existence_immediate
      end

      it "does not regress from confirmed to unconfirmed" do
        compute_metadata.connection.adapter :test do |stub|
          stub.get "/computeMetadata/v1/project/project-id" do |_env|
            [200, flavor_header, project_id]
          end
          stub.get "/computeMetadata/v1/project/unknown-key" do |_env|
            raise Faraday::ConnectionFailed
          end
        end
        compute_metadata.lookup_response "project/project-id"
        assert_equal :confirmed, compute_metadata.existence_immediate
        assert_raises Google::Cloud::Env::MetadataServerNotResponding do
          compute_metadata.lookup_response "project/unknown-key"
        end
        assert_equal :confirmed, compute_metadata.existence_immediate
      end
    end
  end

  describe "lookup" do
    it "gets a value for a good response" do
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/project/project-id" do |_env|
          [200, flavor_header, project_id]
        end
      end
      response = compute_metadata.lookup "project/project-id"
      assert_equal project_id, response
    end

    it "returns nil for a 404 response" do
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/project/project-id" do |_env|
          [404, flavor_header, "Not found"]
        end
      end
      response = compute_metadata.lookup "project/project-id"
      assert_nil response
    end
  end

  describe "expiration_time_of" do
    it "returns false if the data has not been read" do
      assert_equal false, compute_metadata.expiration_time_of("project/project-id")
    end

    it "defaults to a nil lifetime" do
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/project/project-id" do |_env|
          [200, flavor_header, project_id]
        end
      end
      assert_equal project_id, compute_metadata.lookup("project/project-id")
      assert_nil compute_metadata.expiration_time_of("project/project-id")
    end

    it "gets lifetime for an access token" do
      token = {data: "abcdef", expires_in: 1000}
      token_json = JSON.generate token
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/instance/service-accounts/12345/token" do |_env|
          [200, flavor_header, token_json]
        end
      end
      assert_equal token_json, compute_metadata.lookup("instance/service-accounts/12345/token")
      expected_expiry = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 790
      assert_in_delta expected_expiry, compute_metadata.expiration_time_of("instance/service-accounts/12345/token"), 0.1
    end

    it "gets lifetime for an identity token" do
      # Note: the encoded token below includes one of the extra Base64
      # characters (specifically underscore for the urlsafe variant) so this
      # test also checks that urlsafe is properly used to decode.
      token = {data: "???", exp: Time.now.to_i + 1000}
      token_json = JSON.generate token
      token_encoded = Base64.urlsafe_encode64 token_json
      full_token = "12345.#{token_encoded}.67890"
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/instance/service-accounts/12345/identity" do |_env|
          [200, flavor_header, full_token]
        end
      end
      assert_equal full_token, compute_metadata.lookup("instance/service-accounts/12345/identity")
      expected_expiry = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 790
      assert_in_delta expected_expiry, compute_metadata.expiration_time_of("instance/service-accounts/12345/identity"), 0.1
    end

    it "defaults to zero lifetime when failing to parse access token response" do
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/instance/service-accounts/12345/token" do |_env|
          [404, flavor_header, '"Not found"']
        end
      end
      assert_nil compute_metadata.lookup "instance/service-accounts/12345/token"
      expected_expiry = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      assert_in_delta expected_expiry, compute_metadata.expiration_time_of("instance/service-accounts/12345/token")
    end

    it "defaults to zero lifetime when failing to parse identity token response" do
      compute_metadata.connection.adapter :test do |stub|
        stub.get "/computeMetadata/v1/instance/service-accounts/12345/identity" do |_env|
          [404, flavor_header, '"Not found"']
        end
      end
      assert_nil compute_metadata.lookup "instance/service-accounts/12345/identity"
      expected_expiry = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      assert_in_delta expected_expiry, compute_metadata.expiration_time_of("instance/service-accounts/12345/identity")
    end
  end

  describe "check_existence" do
    it "gets set to no if smbios says we're not on GCE" do
      compute_smbios.override_product_name = "Someone Else"
      assert_equal :no, compute_metadata.check_existence
    end

    it "gets set to unconfirmed if smbios says we're on GCE but ping fails" do
      compute_metadata.connection.adapter :test do |stub|
        stub.get "" do |_env|
          raise Faraday::ConnectionFailed
        end
      end
      assert_equal :unconfirmed, compute_metadata.check_existence
    end

    it "does not cache an unconfirmed result" do
      failures_left = 3
      compute_metadata.connection.adapter :test do |stub|
        stub.get "" do |_env|
          failures_left -= 1
          raise Faraday::ConnectionFailed unless failures_left.negative?
          [200, flavor_header, "computeMetadata/\n"]
        end
      end
      assert_equal :unconfirmed, compute_metadata.check_existence
      assert_equal :confirmed, compute_metadata.check_existence
    end

    it "gets set to confirmed if smbios says we're on GCE and ping succeeds" do
      compute_metadata.connection.adapter :test do |stub|
        stub.get "" do |_env|
          [200, flavor_header, "computeMetadata/\n"]
        end
      end
      assert_equal :confirmed, compute_metadata.check_existence
    end

    it "caches a confirmed result" do
      lookup_count = 0
      compute_metadata.connection.adapter :test do |stub|
        stub.get "" do |_env|
          lookup_count += 1
          raise Faraday::ConnectionFailed if lookup_count > 1
          [200, flavor_header, "computeMetadata/\n"]
        end
      end
      assert_equal :confirmed, compute_metadata.check_existence
      assert_equal 1, lookup_count
      assert_equal :confirmed, compute_metadata.check_existence
      assert_equal 1, lookup_count
    end
  end

  describe "ensure_existence" do
    it "raises MetadataServerNotResponding if not on GCE" do
      compute_smbios.override_product_name = "Someone Else"
      assert_raises Google::Cloud::Env::MetadataServerNotResponding do
        compute_metadata.ensure_existence
      end
    end

    it "returns :confirmed if ping succeeds" do
      compute_metadata.connection.adapter :test do |stub|
        stub.get "" do |_env|
          [200, flavor_header, "computeMetadata/\n"]
        end
      end
      assert_equal :confirmed, compute_metadata.ensure_existence
    end

    it "waits for ping to succeed on transient errors" do
      failures_left = 4
      compute_metadata.connection.adapter :test do |stub|
        stub.get "" do |_env|
          failures_left -= 1
          raise Faraday::ConnectionFailed unless failures_left.negative?
          [200, flavor_header, "computeMetadata/\n"]
        end
      end
      assert_equal :confirmed, compute_metadata.ensure_existence
    end

    it "raises a non-transient error" do
      compute_metadata.connection.adapter :test do |stub|
        stub.get "" do |_env|
          raise "non-transient error"
        end
      end
      err = assert_raises RuntimeError do
        compute_metadata.ensure_existence
      end
      assert_equal "non-transient error", err.message
    end
  end
end
