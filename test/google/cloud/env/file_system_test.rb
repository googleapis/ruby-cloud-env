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
require "google/cloud/env/file_system"
require "English"

describe Google::Cloud::Env::FileSystem do
  let(:file_system) { Google::Cloud::Env::FileSystem.new }
  let(:data_dir_path) { File.expand_path "../../../data", __dir__ }
  let(:text_file_path) { File.join data_dir_path, "text-file.txt" }
  let(:binary_file_path) { File.join data_dir_path, "binary-file" }
  let(:missing_file_path) { File.join data_dir_path, "i-dont-exist" }
  let(:text_file_contents) { "Hello, Ruby!" }
  let(:text_file_contents_as_binary) { text_file_contents.encode Encoding::ASCII_8BIT }
  let(:binary_file_contents) { [0, 1, 2, 3].pack("c*") }
  let(:fake_text_file_contents) { "Ruby rocks!" }
  let(:fake_binary_file_contents) { [4, 5, 6, 7].pack("c*") }
  let(:fake_data) {
    {
      text_file_path => fake_text_file_contents,
      binary_file_path => fake_binary_file_contents
    }
  }

  it "returns text content from the file system" do
    assert_equal text_file_contents, file_system.read(text_file_path)
  end

  it "returns binary content from the file system" do
    assert_equal binary_file_contents, file_system.read(binary_file_path, binary: true)
  end

  it "returns nil for a file that doesn't exist" do
    assert_nil file_system.read(missing_file_path)
  end

  it "returns nil for a directory" do
    assert_nil file_system.read(data_dir_path)
  end

  it "reports binary mismatch" do
    assert_equal text_file_contents_as_binary, file_system.read(text_file_path, binary: true)
    assert_raises IOError do
      file_system.read text_file_path, binary: false
    end
    assert_equal text_file_contents_as_binary, file_system.read(text_file_path, binary: true)
  end

  it "supports overrides" do
    file_system.overrides = fake_data
    assert_equal fake_text_file_contents, file_system.read(text_file_path)
    assert_equal fake_binary_file_contents, file_system.read(binary_file_path, binary: true)
    file_system.overrides = nil
    assert_equal text_file_contents, file_system.read(text_file_path)
    assert_equal binary_file_contents, file_system.read(binary_file_path, binary: true)
  end

  it "supports with_overrides" do
    file_system.with_overrides fake_data do
      assert_equal fake_text_file_contents, file_system.read(text_file_path)
      assert_equal fake_binary_file_contents, file_system.read(binary_file_path, binary: true)
    end
    assert_equal text_file_contents, file_system.read(text_file_path)
    assert_equal binary_file_contents, file_system.read(binary_file_path, binary: true)
  end
end
