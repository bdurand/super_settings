# frozen_string_literal: true

require_relative "../spec_helper"

describe SuperSettings do
  describe "load_settings" do
    it "should load the cache" do
      expect_any_instance_of(SuperSettings::LocalCache).to receive(:load_settings)
      SuperSettings.load_settings
    end
  end

  describe "refresh_settings" do
    it "should refresh the cache" do
      expect_any_instance_of(SuperSettings::LocalCache).to receive(:refresh)
      SuperSettings.refresh_settings
    end
  end

  describe "clear_cache" do
    it "should refresh the cache" do
      expect_any_instance_of(SuperSettings::LocalCache).to receive(:reset)
      SuperSettings.clear_cache
    end
  end

  describe "get" do
    it "should get a string value" do
      SuperSettings::Setting.create!(key: "key", value: "foo", value_type: :string)
      SuperSettings.load_settings
      expect(SuperSettings.get("key")).to eq "foo"
    end

    it "should return a default if the key is not defined" do
      expect(SuperSettings.get("key")).to eq nil
      expect(SuperSettings.get("key", "bar")).to eq "bar"
    end

    it "can use hash sytax" do
      SuperSettings::Setting.create!(key: "key", value: "foo", value_type: :string)
      SuperSettings.load_settings
      expect(SuperSettings["key"]).to eq "foo"
    end
  end

  describe "integer" do
    it "should get an integer value" do
      SuperSettings::Setting.create!(key: "key", value: "1", value_type: :string)
      SuperSettings.load_settings
      expect(SuperSettings.integer("key")).to eq 1
    end

    it "should return a default if the key is not defined" do
      expect(SuperSettings.integer("key")).to eq nil
      expect(SuperSettings.integer("key", 2)).to eq 2
    end
  end

  describe "float" do
    it "should get a float value" do
      SuperSettings::Setting.create!(key: "key", value: "1.2", value_type: :string)
      SuperSettings.load_settings
      expect(SuperSettings.float("key")).to eq 1.2
    end

    it "should return a default if the key is not defined" do
      expect(SuperSettings.float("key")).to eq nil
      expect(SuperSettings.float("key", 2.1)).to eq 2.1
    end
  end

  describe "enabled? and disabled?" do
    it "should get a boolean value" do
      SuperSettings::Setting.create!(key: "key.on", value: "on", value_type: :string)
      SuperSettings::Setting.create!(key: "key.off", value: "off", value_type: :boolean)
      SuperSettings.load_settings

      expect(SuperSettings.enabled?("key.on")).to eq true
      expect(SuperSettings.disabled?("key.on")).to eq false

      expect(SuperSettings.enabled?("key.off")).to eq false
      expect(SuperSettings.disabled?("key.off")).to eq true
    end

    it "should return a default if the key is not defined" do
      expect(SuperSettings.enabled?("key")).to eq false
      expect(SuperSettings.disabled?("key")).to eq true

      expect(SuperSettings.enabled?("key", true)).to eq true
      expect(SuperSettings.enabled?("key", false)).to eq false

      expect(SuperSettings.disabled?("key", true)).to eq true
      expect(SuperSettings.disabled?("key", false)).to eq false
    end
  end

  describe "datetime" do
    it "should get a datetime value" do
      SuperSettings::Setting.create!(key: "key", value: "2021-04-14T23:45", value_type: :string)
      SuperSettings.load_settings
      expect(SuperSettings.datetime("key")).to eq Time.new(2021, 4, 14, 23, 45)
    end

    it "should return a default if the key is not defined" do
      expect(SuperSettings.datetime("key")).to eq nil
      time = Time.now
      expect(SuperSettings.datetime("key", time)).to eq time
    end
  end

  describe "array" do
    it "should get an array of strings" do
      SuperSettings::Setting.create!(key: "key", value: "foo", value_type: :string)
      SuperSettings.load_settings
      expect(SuperSettings.array("key")).to eq ["foo"]
    end

    it "should return a default if the key is not defined" do
      expect(SuperSettings.array("key")).to eq nil
      expect(SuperSettings.array("key", [:bar, :baz])).to eq ["bar", "baz"]
    end

    it "should return nil if the key is defined but has a blank value" do
      SuperSettings::Setting.create!(key: "key", value: "", value_type: :string)
      SuperSettings.load_settings
      expect(SuperSettings.array("key")).to eq nil
      expect(SuperSettings.array("key", 1)).to eq ["1"]
    end
  end

  describe "set" do
    it "updates a setting in the database and cache" do
      setting = SuperSettings::Setting.create!(key: "foo", value: "bar")
      SuperSettings.load_settings
      expect(SuperSettings.get("foo")).to eq "bar"
      SuperSettings.set("foo", "bip")
      expect(SuperSettings.get("foo")).to eq "bip"
      expect(SuperSettings::Setting.find_by_key(setting.key).value).to eq "bip"
    end

    it "creates a setting in the database and cache" do
      expect(SuperSettings.get("foo")).to eq nil
      SuperSettings.set("foo", "bip")
      expect(SuperSettings.get("foo")).to eq "bip"
      expect(SuperSettings::Setting.find_by_key("foo").value).to eq "bip"
    end
  end
end
