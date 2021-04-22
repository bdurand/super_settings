# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::LocalCache do
  let(:cache) { SuperSettings::LocalCache.new(ttl: 5) }

  before do
    SuperSettings::Setting.create!(key: "key.1", value: 1, value_type: :integer)
    SuperSettings::Setting.create!(key: "key.2", value: 2, value_type: :integer, deleted: true)
    SuperSettings::Setting.create!(key: "key.3", value: 3, value_type: :integer)
  end

  describe "get key" do
    it "should lazy load a key" do
      expect(cache.size).to eq 0
      expect(cache["key.1"]).to eq 1
      expect(cache.size).to eq 1
      expect(cache).to include("key.1")
    end

    it "should cache a key for the ttl of the cache" do
      cache.ttl = 0.1
      expect(cache["key.1"]).to eq 1
      SuperSettings::Setting.find_by(key: "key.1").update!(value: 10)
      expect(cache["key.1"]).to eq 1
      sleep(0.1)
      expect(cache["key.1"]).to eq 10
    end

    it "should cache miossing keys" do
      cache.ttl = 0.1
      expect(cache["key.4"]).to eq nil
      expect(cache.size).to eq 1
      expect(cache).to include("key.4")

      SuperSettings::Setting.create!(key: "key.4", value: 4, value_type: :integer)
      sleep(0.1)
      expect(cache["key.4"]).to eq 4
    end
  end

  describe "load" do
    it "should load all non-deleted keys" do
      cache.load
      expect(cache.size).to eq 2
      expect(cache).to include("key.1")
      expect(cache).to_not include("key.2")
      expect(cache).to include("key.3")
    end
  end

  describe "clear" do
    it "should clear the cache" do
      cache.load
      cache.clear
      expect(cache.size).to eq 0
      expect(cache["key.1"]).to eq 1
    end
  end

  describe "refresh" do
    it "should do nothing if no settings are loaded" do
      expect(SuperSettings::Setting).to_not receive(:last_updated_at)
      expect(cache.size).to eq 0
    end

    it "should load updated records" do
      cache.load
      SuperSettings::Setting.with_deleted.find_by(key: "key.1").update!(value: 10)
      SuperSettings::Setting.with_deleted.find_by(key: "key.2").update!(deleted: false)
      SuperSettings::Setting.with_deleted.find_by(key: "key.3").update!(deleted: true)
      expect(cache["key.1"]).to eq 1
      expect(cache["key.2"]).to eq 2
      expect(cache["key.3"]).to eq 3
      cache.refresh
      expect(cache["key.1"]).to eq 10
      expect(cache["key.2"]).to eq 2
      expect(cache["key.3"]).to eq nil
    end
  end
end
