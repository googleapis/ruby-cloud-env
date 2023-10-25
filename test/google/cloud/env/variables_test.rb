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
require "google/cloud/env/variables"

describe Google::Cloud::Env::Variables do
  let(:variables) { Google::Cloud::Env::Variables.new }
  let(:fake_home) { "fake-home" }
  let(:fake_data) { { "HOME" => fake_home } }
  let(:empty_backing_data) { {} }

  it "returns the value from the environment" do
    assert_equal ENV["HOME"], variables["HOME"]
  end

  it "supports modifying the backing data" do
    variables.backing_data = fake_data
    assert_equal fake_home, variables["HOME"]
    variables.backing_data = ENV
    assert_equal ENV["HOME"], variables["HOME"]
  end

  it "supports modifying the backing data in a block" do
    variables.with_backing_data fake_data do
      assert_equal fake_home, variables["HOME"]
    end
    assert_equal ENV["HOME"], variables["HOME"]
  end

  it "completely replaces backing data" do
    refute_nil variables["HOME"]
    variables.backing_data = empty_backing_data
    assert_nil variables["HOME"]
    variables.backing_data = ENV
    refute_nil variables["HOME"]
  end
end
