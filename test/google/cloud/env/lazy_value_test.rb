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
require "google/cloud/env/lazy_value"

describe Google::Cloud::Env::LazyValue do
  describe "#get" do
    it "returns the correct value" do
      cache = Google::Cloud::Env::LazyValue.new do
        1
      end
      assert_equal 1, cache.get
    end

    it "passes extra arguments" do
      cache = Google::Cloud::Env::LazyValue.new do |arg1, arg2|
        arg1 + arg2
      end
      assert_equal 2, cache.get(3, -1)
    end

    it "calls the block only the first time" do
      count = 0
      cache = Google::Cloud::Env::LazyValue.new do
        count += 1
        3
      end
      assert_equal 0, count
      assert_equal 3, cache.get
      assert_equal 1, count
      assert_equal 3, cache.get
      assert_equal 1, count
      assert_equal 3, cache.get
      assert_equal 1, count
    end

    it "causes threads to wait if a block is already running" do
      count = 0
      cache = Google::Cloud::Env::LazyValue.new do
        sleep 0.1
        count += 1
        4
      end
      value1 = value2 = nil
      thread1 = Thread.new do
        value1 = cache.get
      end
      thread2 = Thread.new do
        value2 = cache.get
      end
      thread1.join
      thread2.join
      assert_equal 4, value1
      assert_equal 4, value2
      assert_equal 1, count
    end

    it "raises exceptions" do
      cache = Google::Cloud::Env::LazyValue.new do
        raise "whoops5"
      end
      err = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops5", err.message
    end

    it "caches and reraises exceptions" do
      count = 0
      cache = Google::Cloud::Env::LazyValue.new do
        count += 1
        raise "whoops6"
      end
      assert_equal 0, count
      err1 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops6", err1.message
      assert_equal 1, count
      err2 = assert_raises RuntimeError do
        cache.get
      end
      assert_same err2, err1
      assert_equal 1, count
    end

    it "retries and succeeds" do
      count = 0
      retries = Google::Cloud::Env::Retries.new max_tries: 3
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        count += 1
        raise "whoops7" unless count >= 3
        7
      end
      assert_equal 0, count
      err1 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops7", err1.message
      assert_equal 1, count
      err2 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops7", err2.message
      refute_same err1, err2
      assert_equal 2, count
      assert_equal 7, cache.get
      assert_equal 3, count
      assert_equal 7, cache.get
      assert_equal 3, count
    end

    it "retries and fails finally" do
      count = 0
      retries = Google::Cloud::Env::Retries.new max_tries: 3
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        count += 1
        raise "whoops8"
      end
      assert_equal 0, count
      err1 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops8", err1.message
      assert_equal 1, count
      err2 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops8", err2.message
      refute_same err1, err2
      assert_equal 2, count
      err3 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops8", err3.message
      refute_same err2, err3
      assert_equal 3, count
      err4 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops8", err4.message
      assert_same err3, err4
      assert_equal 3, count
    end

    it "does not retry until the previous try has completed" do
      count = 0
      retries = Google::Cloud::Env::Retries.new max_tries: 3
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        sleep 0.1
        count += 1
        raise "whoops9" unless count >= 2
        9
      end
      thread1 = Thread.new do
        err1 = assert_raises RuntimeError do
          cache.get
        end
        assert_equal "whoops9", err1.message
      end
      thread2 = Thread.new do
        err2 = assert_raises RuntimeError do
          cache.get
        end
        assert_equal "whoops9", err2.message
      end
      thread1.join
      thread2.join
      assert_equal 1, count
      value3 = value4 = nil
      thread3 = Thread.new do
        value3 = cache.get
      end
      thread4 = Thread.new do
        value4 = cache.get
      end
      thread3.join
      thread4.join
      assert_equal 9, value3
      assert_equal 9, value4
      assert_equal 2, count
      assert_equal 9, cache.get
      assert_equal 2, count
    end

    it "waits for a delay before retrying" do
      count = 0
      retries = Google::Cloud::Env::Retries.new max_tries: 3, initial_delay: 0.1
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        count += 1
        raise "whoops10" unless count >= 2
        10
      end
      err1 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops10", err1.message
      assert_equal 1, count
      err2 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops10", err2.message
      assert_equal 1, count
      sleep 0.2
      assert_equal 10, cache.get
      assert_equal 2, count
      assert_equal 10, cache.get
      assert_equal 2, count
    end

    it "retries until a max time" do
      count = 0
      retries = Google::Cloud::Env::Retries.new max_time: 0.2, initial_delay: 0.13, max_tries: nil
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        count += 1
        raise "whoops11"
      end
      err1 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops11", err1.message
      assert_equal 1, count
      err2 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops11", err2.message
      assert_equal 1, count
      sleep 0.15
      err3 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops11", err3.message
      assert_equal 2, count
      err4 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops11", err4.message
      assert_equal 2, count
      sleep 0.15
      err5 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops11", err5.message
      assert_equal 2, count
    end

    it "includes time elapsed in a retry delay" do
      count = 0
      retries = Google::Cloud::Env::Retries.new max_tries: 3, initial_delay: 0.2, delay_includes_time_elapsed: true
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        sleep 0.1
        count += 1
        raise "whoops12" unless count >= 2
        12
      end
      err1 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops12", err1.message
      assert_equal 1, count
      err2 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "whoops12", err2.message
      assert_equal 1, count
      sleep 0.15
      assert_equal 12, cache.get
      assert_equal 2, count
      assert_equal 12, cache.get
      assert_equal 2, count
    end

    it "does not allow thread re-entry" do
      cache = nil
      cache = Google::Cloud::Env::LazyValue.new do
        cache.get
      end
      err = assert_raises ThreadError do
        cache.get
      end
      assert_equal "deadlock: tried to call LazyValue#get from its own computation", err.message
    end

    it "returns an expiring value" do
      count = 0
      cache = Google::Cloud::Env::LazyValue.new do
        count += 1
        Google::Cloud::Env::LazyValue.expiring_value 0.1, 10
      end
      assert_equal 10, cache.get
      assert_equal 1, count
      assert_equal 10, cache.get
      assert_equal 1, count
      sleep 0.2
      assert_equal 10, cache.get
      assert_equal 2, count
    end

    it "raises an expiring error" do
      count = 0
      cache = Google::Cloud::Env::LazyValue.new do
        count += 1
        Google::Cloud::Env::LazyValue.raise_expiring_error 0.1, "count=#{count}"
      end
      err1 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "count=1", err1.message
      assert_equal 1, count
      err2 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "count=1", err2.message
      assert_equal 1, count
      sleep 0.2
      err3 = assert_raises RuntimeError do
        cache.get
      end
      assert_equal "count=2", err3.message
      assert_equal 2, count
    end

    it "successfully exits backfill" do
      count = 0
      cache = Google::Cloud::Env::LazyValue.new do
        count += 1
        sleep 0.2
        Google::Cloud::Env::LazyValue.expiring_value 0, 11
      end
      Thread.new do
        cache.get
      end
      sleep 0.1
      assert_equal 11, cache.get
      assert_equal 1, count
      assert_equal 11, cache.get
      assert_equal 2, count
    end
  end

  describe "#await" do
    it "returns the value" do
      cache = Google::Cloud::Env::LazyValue.new do
        1
      end
      assert_equal 1, cache.await
    end

    it "passes extra arguments" do
      cache = Google::Cloud::Env::LazyValue.new do |arg1, arg2|
        arg1 + arg2
      end
      assert_equal 2, cache.await(3, -1)
    end

    it "repeatedly calls get until success" do
      count = 0
      retries = Google::Cloud::Env::Retries.new max_tries: 10
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        count += 1
        raise "whoops2" unless count >= 4
        3
      end
      assert_equal 3, cache.await(max_tries: 10)
      assert_equal 4, count
    end

    it "honors max_tries" do
      count = 0
      retries = Google::Cloud::Env::Retries.new max_tries: 10
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        count += 1
        raise "whoops3"
      end
      err = assert_raises RuntimeError do
        cache.await max_tries: 4
      end
      assert_equal "whoops3", err.message
      assert_equal 4, count
    end

    it "honors max_time" do
      count = 0
      retries = Google::Cloud::Env::Retries.new max_tries: 10
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        count += 1
        sleep 0.2
        raise "whoops4"
      end
      err = assert_raises RuntimeError do
        cache.await max_time: 0.5, max_tries: nil
      end
      assert_equal "whoops4", err.message
      assert_equal 3, count
    end

    it "uses the cache's retry interval" do
      count = 0
      retries = Google::Cloud::Env::Retries.new max_tries: 10, initial_delay: 0.1
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        count += 1
        raise "whoops5"
      end
      err = assert_raises RuntimeError do
        cache.await max_time: 0.25, max_tries: 10
      end
      assert_equal "whoops5", err.message
      assert_equal 3, count
    end

    class MyError < StandardError
    end

    it "honors transient_errors" do
      count = 0
      retries = Google::Cloud::Env::Retries.new max_tries: 10
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        count += 1
        raise MyError if count < 3
        raise "whoops6"
      end
      err = assert_raises RuntimeError do
        cache.await transient_errors: [MyError], max_tries: 10
      end
      assert_equal "whoops6", err.message
      assert_equal 3, count
    end
  end

  describe "#expire!" do
    it "does nothing if not finished" do
      cache = Google::Cloud::Env::LazyValue.new do
        1
      end
      assert_equal false, cache.expire!
    end

    it "forces recalculation if computation is finished" do
      count = 0
      cache = Google::Cloud::Env::LazyValue.new do
        count += 1
        2
      end
      assert_equal 2, cache.get
      assert_equal 1, count
      assert_equal true, cache.expire!
      assert_equal 2, cache.get
      assert_equal 2, count
    end

    it "does nothing if computation is in progress" do
      count = 0
      cache = Google::Cloud::Env::LazyValue.new do
        count += 1
        sleep 0.3
        3
      end
      value1 = result2 = nil
      thread1 = Thread.new do
        value1 = cache.get
      end
      thread2 = Thread.new do
        sleep 0.1
        result2 = cache.expire!
      end
      thread1.join
      thread2.join
      assert_equal 3, value1
      assert_equal false, result2
      assert_equal 1, count
      assert_equal 3, cache.get
      assert_equal 1, count
    end
  end

  describe "#internal_state" do
    it "reflects initial pending state" do
      cache = Google::Cloud::Env::LazyValue.new do
        1
      end
      assert_equal [:pending, nil, nil], cache.internal_state
    end

    it "reflects pending state after failed computation and no delay" do
      retries = Google::Cloud::Env::Retries.new max_tries: 3
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        raise "whoops"
      end
      err = assert_raises RuntimeError do
        cache.get
      end
      assert_equal [:pending, err, nil], cache.internal_state
    end

    it "reflects pending state after failed computation with delay" do
      retries = Google::Cloud::Env::Retries.new max_tries: 3, initial_delay: 0.1
      cache = Google::Cloud::Env::LazyValue.new retries: retries do
        raise "whoops"
      end
      err = assert_raises RuntimeError do
        cache.get
      end
      assert_equal :pending, cache.internal_state[0]
      assert_equal err, cache.internal_state[1]
      expected_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.1
      assert_in_delta expected_time, cache.internal_state[2], 0.05
    end

    it "reflects computing state" do
      cache = Google::Cloud::Env::LazyValue.new do
        sleep 0.2
        2
      end
      start_time = nil
      thread = Thread.new do
        start_time = Process.clock_gettime Process::CLOCK_MONOTONIC
        cache.get
      end
      sleep 0.1
      assert_equal :computing, cache.internal_state[0]
      assert_in_delta start_time, cache.internal_state[2], 0.05
      thread.join
    end

    it "reflects success state with no expiration" do
      cache = Google::Cloud::Env::LazyValue.new do
        3
      end
      assert_equal 3, cache.get
      assert_equal [:success, 3, nil], cache.internal_state
    end

    it "reflects success state with expiration" do
      cache = Google::Cloud::Env::LazyValue.new do
        Google::Cloud::Env::LazyValue.expiring_value 1, 3
      end
      assert_equal 3, cache.get
      expected_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
      assert_equal :success, cache.internal_state[0]
      assert_equal 3, cache.internal_state[1]
      assert_in_delta expected_time, cache.internal_state[2], 0.05
    end

    it "reflects error state with no expiration" do
      cache = Google::Cloud::Env::LazyValue.new do
        raise "whoops4"
      end
      err = assert_raises RuntimeError do
        cache.get
      end
      assert_equal [:failed, err, nil], cache.internal_state
    end

    it "reflects error state with expiration" do
      cache = Google::Cloud::Env::LazyValue.new do
        Google::Cloud::Env::LazyValue.raise_expiring_error 1, "whoops5"
      end
      err = assert_raises RuntimeError do
        cache.get
      end
      expected_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
      assert_equal :failed, cache.internal_state[0]
      assert_equal err, cache.internal_state[1]
      assert_in_delta expected_time, cache.internal_state[2], 0.05
    end
  end
end

describe Google::Cloud::Env::LazyDict do
  let :lazy_dict do
    count = 0
    Google::Cloud::Env::LazyDict.new do |num, suffix = ""|
      count += 1
      "#{num}-#{count}#{suffix}"
    end
  end

  describe "#get" do
    it "returns the correct value for keys" do
      assert_equal "1-1", lazy_dict.get(1)
      assert_equal "12-2", lazy_dict.get(12)
    end

    it "calls the block only the first time" do
      assert_equal "1-1", lazy_dict.get(1)
      assert_equal "1-1", lazy_dict.get(1)
      assert_equal "12-2", lazy_dict.get(12)
      assert_equal "12-2", lazy_dict.get(12)
      assert_equal "1-1", lazy_dict.get(1)
    end

    it "passes extra arguments" do
      assert_equal "1-1foo", lazy_dict.get(1, "foo")
      assert_equal "12-2bar", lazy_dict.get(12, "bar")
      assert_equal "1-1foo", lazy_dict.get(1, "baz")
    end
  end

  describe "#expire!" do
    it "expires the correct key" do
      assert_equal "1-1", lazy_dict.get(1)
      assert_equal "12-2", lazy_dict.get(12)
      assert_equal true, lazy_dict.expire!(1)
      assert_equal "1-3", lazy_dict.get(1)
      assert_equal "12-2", lazy_dict.get(12)
    end
  end

  describe "#expire_all!" do
    it "returns the keys expired" do
      assert_equal "1-1", lazy_dict.get(1)
      assert_equal false, lazy_dict.expire!(12)
      assert_equal [1], lazy_dict.expire_all!
      assert_equal "1-2", lazy_dict.get(1)
    end
  end
end
