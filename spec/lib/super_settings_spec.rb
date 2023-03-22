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
      expect(SuperSettings.disabled?("key", true)).to eq false
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

  describe "structured" do
    before do
      SuperSettings::Setting.create!(key: "A1.B1.C-1", value: "foo")
      SuperSettings::Setting.create!(key: "A1.B1.C-2", value: "bar")
      SuperSettings::Setting.create!(key: "A1.B2", value: 2, value_type: :integer)
      SuperSettings::Setting.create!(key: "A2.B1.C-1", value: "bip")
      SuperSettings::Setting.create!(key: "A2.B1.C-2", value: nil)
      SuperSettings.load_settings
    end

    it "should return a nested hash from all the settings if no key is provided" do
      expect(SuperSettings.structured).to eq({
        "A1" => {
          "B1" => {
            "C-1" => "foo",
            "C-2" => "bar"
          },
          "B2" => 2
        },
        "A2" => {
          "B1" => {
            "C-1" => "bip",
            "C-2" => nil
          }
        }
      })
    end

    it "should return a nested hash from settings matching the key" do
      expect(SuperSettings.structured(:A1)).to eq({
        "B1" => {
          "C-1" => "foo",
          "C-2" => "bar"
        },
        "B2" => 2
      })

      expect(SuperSettings.structured("A1.B1")).to eq({
        "C-1" => "foo",
        "C-2" => "bar"
      })
    end

    it "should use a custom delimiter" do
      expect(SuperSettings.structured("A1.B1.C", nil, delimiter: "-")).to eq({
        "1" => "foo",
        "2" => "bar"
      })
    end

    it "should allow setting a maximum depth to the hash" do
      expect(SuperSettings.structured("A1", nil, max_depth: 1)).to eq({
        "B1.C-1" => "foo",
        "B1.C-2" => "bar",
        "B2" => 2
      })
    end

    it "should return an empty hash value if there is not a matching setting key" do
      SuperSettings.get("A3.B1")
      expect(SuperSettings.structured("A3")).to eq({})
    end

    it "should return a default if the key is not defined" do
      expect(SuperSettings.structured("A3")).to eq({})
      expect(SuperSettings.structured("A3", {"foo" => "bar"})).to eq({"foo" => "bar"})
    end

    it "should return a cached value" do
      hash = SuperSettings.structured
      expect(SuperSettings.structured.object_id).to eq hash.object_id
      SuperSettings.refresh_settings
      expect(SuperSettings.structured).to eq hash
      expect(SuperSettings.structured.object_id).to_not eq hash.object_id
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
