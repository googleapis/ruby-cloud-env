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
require "google/cloud/env/compute_smbios"

describe Google::Cloud::Env::ComputeSMBIOS do
  let(:compute_smbios) { Google::Cloud::Env::ComputeSMBIOS.new }

  it "gets data on Linux" do
    skip unless `uname`.strip == "Linux"
    assert_kind_of String, compute_smbios.product_name
    assert_equal :linux, compute_smbios.product_name_source
  end

  it "gets data on Windows" do
    skip unless ::RbConfig::CONFIG["host_os"] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/
    assert_kind_of String, compute_smbios.product_name
    assert_equal :windows, compute_smbios.product_name_source
  end

  it "overrides product_name" do
    refute_equal "My Product", compute_smbios.product_name
    refute_equal :override, compute_smbios.product_name_source
    compute_smbios.override_product_name = "My Product"
    assert_equal "My Product", compute_smbios.product_name
    assert_equal :override, compute_smbios.product_name_source
    compute_smbios.override_product_name = nil
    refute_equal "My Product", compute_smbios.product_name
    refute_equal :override, compute_smbios.product_name_source
  end

  it "overrides product_name in a block" do
    refute_equal "My Product", compute_smbios.product_name
    refute_equal :override, compute_smbios.product_name_source
    compute_smbios.with_override_product_name "My Product" do
      assert_equal "My Product", compute_smbios.product_name
      assert_equal :override, compute_smbios.product_name_source
    end
    refute_equal "My Product", compute_smbios.product_name
    refute_equal :override, compute_smbios.product_name_source
  end
end
