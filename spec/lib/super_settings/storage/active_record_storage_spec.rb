# frozen_string_literal: true

require_relative "../../../spec_helper"

describe SuperSettings::Storage::ActiveRecordStorage do
  describe "all_settings" do
    it "should return all settings" do
      setting_1 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_1", raw_value: "1")
      setting_1.store!
      setting_2 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_2", deleted: true)
      setting_2.store!
      setting_3 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_3", raw_value: "3")
      setting_3.store!
      settings = SuperSettings::Storage::ActiveRecordStorage.all_settings
      expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::ActiveRecordStorage]
      expect(settings.collect(&:key)).to match_array(["setting_1", "setting_2", "setting_3"])
    end
  end

  describe "active_settings" do
    it "should return only non-deleted settings" do
      setting_1 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_1", raw_value: "1")
      setting_1.store!
      setting_2 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_2", deleted: true)
      setting_2.store!
      setting_3 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_3", raw_value: "3")
      setting_3.store!
      settings = SuperSettings::Storage::ActiveRecordStorage.active_settings
      expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::ActiveRecordStorage]
      expect(settings.collect(&:key)).to match_array(["setting_1", "setting_3"])
    end
  end

  describe "updated_since" do
    it "should return settings updated since a timestamp" do
      setting_1 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_1", raw_value: "1", updated_at: 10.minutes.ago)
      setting_1.store!
      setting_2 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_2", raw_value: "2", updated_at: 5.minutes.ago)
      setting_2.store!
      setting_3 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_3", raw_value: "3")
      setting_3.store!
      settings = SuperSettings::Storage::ActiveRecordStorage.updated_since(6.minutes.ago)
      expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::ActiveRecordStorage]
      expect(settings.collect(&:key)).to match_array(["setting_2", "setting_3"])
    end
  end

  describe "find_by_key" do
    it "should return settings updated since a timestamp" do
      setting_1 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_1", raw_value: "1", updated_at: 10.minutes.ago)
      setting_1.store!
      setting_2 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_2", raw_value: "2", updated_at: 5.minutes.ago)
      setting_2.store!
      expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting_1")).to eq setting_1
      expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting_2")).to eq setting_2
      expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("not_exist")).to eq nil
      expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting_1").stored?).to eq true
    end
  end

  describe "last_updated_at" do
    it "should return the last time a setting was updated" do
      setting_1 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_1", raw_value: "1", updated_at: 10.minutes.ago)
      setting_1.store!
      setting_2 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_2", raw_value: "2", updated_at: Time.at(5.minutes.ago.to_i))
      setting_2.store!
      expect(SuperSettings::Storage::ActiveRecordStorage.last_updated_at).to eq setting_2.updated_at
    end
  end

  describe "attributes" do
    it "should cast all the attributes" do
      setting = SuperSettings::Storage::ActiveRecordStorage.new(key: "key", raw_value: "1", value_type: "integer", description: "text", updated_at: Time.now, created_at: 1.minute.ago)
      expect(setting.stored?).to eq false
      setting.store!

      expect(setting.stored?).to eq true
      expect(setting.key).to eq "key"
      expect(setting.raw_value).to eq "1"
      expect(setting.value_type).to eq "integer"
      expect(setting.description).to eq "text"
      expect(setting.deleted?).to eq false
      expect(setting.updated_at).to be_a(Time)
      expect(setting.created_at).to be_a(Time)
    end
  end

  describe "history" do
    it "should fetch the setting history" do
      setting = SuperSettings::Storage::ActiveRecordStorage.new(key: "key", raw_value: "1")
      setting.store!
      setting.create_history(value: "1", changed_by: "me", created_at: 3.minutes.ago)
      setting.create_history(value: "2", changed_by: "you", created_at: 2.minutes.ago)
      setting.create_history(deleted: true, changed_by: "Bob", created_at: 1.minute.ago)
      histories = setting.history
      expect(histories.collect(&:value)).to eq [nil, "2", "1"]
      expect(histories.collect(&:deleted?)).to eq [true, false, false]
      expect(histories.collect(&:changed_by)).to eq ["Bob", "you", "me"]
      expect(setting.history(limit: 1, offset: 1).collect(&:value)).to eq ["2"]
      expect(setting.history(limit: 1, offset: 2).collect(&:value)).to eq ["1"]
    end
  end

  describe "redact_history" do
    it "should remove all values from the history" do
      setting = SuperSettings::Storage::ActiveRecordStorage.new(key: "key", raw_value: "1")
      setting.store!
      setting.create_history(value: "1", changed_by: "me", created_at: 2.minute.ago)
      setting.create_history(value: "2", changed_by: "you", created_at: 1.minute.ago)
      setting.send(:redact_history!)
      histories = setting.history
      expect(histories.collect(&:value)).to eq [nil, nil]
      expect(histories.collect(&:changed_by)).to eq ["you", "me"]
    end
  end
end
