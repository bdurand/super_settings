# frozen_string_literal: true

require_relative "../../spec_helper"

class TestJsonStorage < SuperSettings::Storage::JSONStorage
  class << self
    def current_json(json)
      Thread.current[:test_json_storage_json] = json
      Thread.current[:test_json_storage_history] = {}
      begin
        yield
      ensure
        Thread.current[:test_json_storage_json] = nil
        Thread.current[:test_json_storage_history] = nil
      end
    end

    protected

    def settings_json_payload
      Thread.current[:test_json_storage_json]
    end

    def save_settings_json(json)
      Thread.current[:test_json_storage_json] = json
    end

    def save_history_json(key, json)
      all_history = Thread.current[:test_json_storage_history] ||= {}
      all_history[key] = json
    end
  end

  protected

  def fetch_history_json
    all_history = Thread.current[:test_json_storage_history] ||= {}
    all_history[key]
  end
end

describe SuperSettings::Storage::JSONStorage do
  let(:setting_1) do
    TestJsonStorage.new(
      key: "setting_1",
      raw_value: "1",
      description: "Setting 1",
      value_type: "integer",
      updated_at: Time.now - 100,
      created_at: Time.now - 100
    )
  end

  let(:setting_2) do
    TestJsonStorage.new(
      key: "setting_2",
      raw_value: "test",
      description: "Setting 2",
      value_type: "string",
      updated_at: Time.now - 50,
      created_at: Time.now - 50
    )
  end

  let(:setting_3) do
    TestJsonStorage.new(
      key: "setting_3",
      raw_value: "3",
      description: "Setting 3",
      value_type: "integer",
      updated_at: Time.now,
      created_at: Time.now,
      deleted: true
    )
  end

  let(:json) do
    JSON.dump([setting_1, setting_2, setting_3].collect(&:as_json))
  end

  describe ".all" do
    it "should load all settings" do
      TestJsonStorage.current_json(json) do
        expect(TestJsonStorage.all.map(&:key)).to eq(["setting_1", "setting_2", "setting_3"])
      end
    end

    it "is empty if the json is nil" do
      TestJsonStorage.current_json(nil) do
        expect(TestJsonStorage.all).to eq([])
      end
    end

    it "is empty if the json is empty" do
      TestJsonStorage.current_json("") do
        expect(TestJsonStorage.all).to eq([])
      end
    end
  end

  describe ".updated_since" do
    it "should return updated since a timestamp" do
      TestJsonStorage.current_json(json) do
        expect(TestJsonStorage.updated_since(Time.now - 75).map(&:key)).to eq(["setting_2", "setting_3"])
      end
    end
  end

  describe ".find_by_key" do
    it "should find a non-deleted setting by key" do
      TestJsonStorage.current_json(json) do
        expect(TestJsonStorage.find_by_key("setting_1")).to eq(setting_1)
        expect(TestJsonStorage.find_by_key("setting_2")).to eq(setting_2)
        expect(TestJsonStorage.find_by_key("not_exist")).to eq(nil)
      end
    end
  end

  describe ".save_all" do
    it "should save all settings by calling save_json with the entire payload" do
      TestJsonStorage.current_json(json) do
        setting_1.raw_value = "-1"
        setting_2.deleted = true
        new_setting = TestJsonStorage.new(
          key: "setting_4",
          raw_value: "4",
          description: "Setting 4",
          value_type: "integer"
        )

        TestJsonStorage.transaction do
          setting_1.save!
          setting_2.save!
          new_setting.save!
        end

        saved_settings = TestJsonStorage.parse_settings(TestJsonStorage.send(:settings_json_payload))
        expect(saved_settings.map(&:key)).to eq(["setting_1", "setting_2", "setting_3", "setting_4"])
        expect(saved_settings.map(&:raw_value)).to eq(["-1", "test", "3", "4"])
        expect(saved_settings.map(&:deleted?)).to eq([false, true, true, false])
      end
    end

    describe "#create_history" do
      it "should return the history of a setting" do
        TestJsonStorage.current_json(json) do
          Thread.current[:test_json_storage_history]["setting_1"] = JSON.dump([
            {value: "1", changed_by: "user_1", created_at: Time.now - 100},
            {value: "2", changed_by: "user_2", created_at: Time.now - 50}
          ])
          setting = TestJsonStorage.find_by_key("setting_1")
          expect(setting.history.map(&:value)).to eq(["2", "1"])
          expect(setting.history.map(&:changed_by)).to eq(["user_2", "user_1"])
        end
      end
    end

    describe "#history" do
      it "should return the history of a setting" do
        setting_1.create_history(changed_by: "user_1", value: "1", created_at: Time.now - 100)
        setting_1.create_history(changed_by: "user_2", value: "2", created_at: Time.now - 50)
        setting_1.create_history(changed_by: "user_3", value: "3", created_at: Time.now)
        setting_1.save!
        expect(setting_1.history.map(&:class).uniq).to eq([SuperSettings::HistoryItem])
        expect(setting_1.history.map(&:value)).to eq(["3", "2", "1"])
        expect(setting_1.history(limit: 2).map(&:value)).to eq(["3", "2"])
        expect(setting_1.history(offset: 1).map(&:value)).to eq(["2", "1"])
      end
    end
  end
end
