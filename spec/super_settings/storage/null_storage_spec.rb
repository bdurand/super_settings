# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::Storage::NullStorage do
  describe "all" do
    it "should return an empty array" do
      settings = SuperSettings::Storage::NullStorage.all
      expect(settings).to eq []
    end
  end

  describe "active" do
    it "should return an empty array" do
      settings = SuperSettings::Storage::NullStorage.active
      expect(settings).to eq []
    end
  end

  describe "updated_since" do
    it "should return an empty array" do
      settings = SuperSettings::Storage::NullStorage.updated_since(Time.now - 60)
      expect(settings).to eq []
    end
  end

  describe "find_by_key" do
    it "should return nil" do
      setting = SuperSettings::Storage::NullStorage.find_by_key("key")
      expect(setting).to be_nil
    end
  end

  describe "last_updated_at" do
    it "should return nil" do
      expect(SuperSettings::Storage::NullStorage.last_updated_at).to be_nil
    end
  end

  describe "history" do
    it "should an empty array" do
      setting = SuperSettings::Storage::NullStorage.new(key: "key", raw_value: "1")
      histories = setting.history
      expect(histories).to eq []
    end
  end

  describe "load_asynchronous" do
    it "should be false" do
      expect(SuperSettings::Storage::NullStorage.load_asynchronous?).to eq false
      SuperSettings::Storage::NullStorage.load_asynchronous = true
      expect(SuperSettings::Storage::NullStorage.load_asynchronous?).to eq false
    end
  end
end
