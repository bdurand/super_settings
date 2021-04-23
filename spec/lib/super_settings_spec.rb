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
      expect(SuperSettings.get("key")).to eq "foo"
    end

    it "should return a default if the key is not defined" do
      expect(SuperSettings.get("key")).to eq nil
      expect(SuperSettings.get("key", "bar")).to eq "bar"
    end
  end

  describe "integer" do
    it "should get an integer value" do
      SuperSettings::Setting.create!(key: "key", value: "1", value_type: :string)
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
      expect(SuperSettings.float("key")).to eq 1.2
    end

    it "should return a default if the key is not defined" do
      expect(SuperSettings.float("key")).to eq nil
      expect(SuperSettings.float("key", 2.1)).to eq 2.1
    end
  end

  describe "enabled?" do
    it "should get a boolean value" do
      SuperSettings::Setting.create!(key: "key.on", value: "on", value_type: :string)
      SuperSettings::Setting.create!(key: "key.off", value: "off", value_type: :string)
      expect(SuperSettings.enabled?("key.on")).to eq true
      expect(SuperSettings.enabled?("key.off")).to eq true
    end

    it "should return a default if the key is not defined" do
      expect(SuperSettings.enabled?("key")).to eq false
      expect(SuperSettings.enabled?("key", true)).to eq true
    end
  end

  describe "datetime" do
    it "should get a datetime value" do
      SuperSettings::Setting.create!(key: "key", value: "2021-04-14T23:45", value_type: :string)
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
      expect(SuperSettings.array("key")).to eq ["foo"]
    end

    it "should return a default if the key is not defined" do
      expect(SuperSettings.array("key")).to eq []
      expect(SuperSettings.array("key", ["bar", "baz"])).to eq ["bar", "baz"]
    end
  end

  describe "hash" do
    before do
      SuperSettings::Setting.create!(key: "A1.B1.C1", value: "foo")
      SuperSettings::Setting.create!(key: "A1.B1.C2", value: "bar")
      SuperSettings::Setting.create!(key: "A1.B2", value: 2, value_type: :integer)
      SuperSettings::Setting.create!(key: "A2.B1.C1", value: "bip")
      SuperSettings::Setting.create!(key: "A2.B1.C2", value: nil)
    end

    it "should return a nested hash from all the settings if no key is provided" do
      expect(SuperSettings.hash).to eq({
        "A1" => {
          "B1" => {
            "C1" => "foo",
            "C2" => "bar"
          },
          "B2" => 2
        },
        "A2" => {
          "B1" => {
            "C1" => "bip"
          }
        }
      })
    end

    it "should return a nested hash from settings matching the key" do
      expect(SuperSettings.hash(:A1)).to eq({
        "B1" => {
          "C1" => "foo",
          "C2" => "bar"
        },
        "B2" => 2
      })

      expect(SuperSettings.hash("A1.B1")).to eq({
        "C1" => "foo",
        "C2" => "bar"
      })
    end

    it "should not return an empty hash value if there is a matching setting key" do
      expect(SuperSettings.hash("A1.B1.C1")).to eq({})
    end

    it "should return a default if the keys are not defined" do
      expect(SuperSettings.hash("A3")).to eq({})
      expect(SuperSettings.hash("A3", {"foo" => "bar"})).to eq({"foo" => "bar"})
    end
  end
end
