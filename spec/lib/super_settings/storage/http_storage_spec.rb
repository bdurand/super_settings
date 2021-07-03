# frozen_string_literal: true

require_relative "../../../spec_helper"

describe SuperSettings::Storage::HttpStorage do
  describe "http settings" do
    it "should add query parameters on a GET request" do
      allow(SuperSettings::Storage::HttpStorage).to receive(:query_params).and_return({foo: "bar"})
      stub_request(:get, "https://example.com/settings/").with(query: {foo: "bar"}).to_return(body: [].to_json, headers: {"Content-Type" => "application/json"})
      SuperSettings::Storage::HttpStorage.all_settings
    end

    it "should add headers to the request" do
      allow(SuperSettings::Storage::HttpStorage).to receive(:headers).and_return({"Foo" => "bar"})
      stub_request(:get, "https://example.com/settings/").with(headers: {"Accept" => "application/json", "Foo" => "bar"}).to_return(body: [].to_json, headers: {"Content-Type" => "application/json"})
      SuperSettings::Storage::HttpStorage.all_settings
    end
  end

  describe "all_settings" do
    it "should return all settings" do
      setting_1 = SuperSettings::Setting.new(key: "setting_1", value: "1")
      setting_2 = SuperSettings::Setting.new(key: "setting_2", deleted: true)
      setting_3 = SuperSettings::Setting.new(key: "setting_3", value: "3")
      payload = [setting_1, setting_2, setting_3]
      stub_request(:get, "https://example.com/settings/").to_return(body: payload.to_json, headers: {"Content-Type" => "application/json"})
      settings = SuperSettings::Storage::HttpStorage.all_settings
      expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::HttpStorage]
      expect(settings.collect(&:key)).to match_array(["setting_1", "setting_2", "setting_3"])
    end
  end

  describe "active_settings" do
    it "should return only non-deleted settings" do
      setting_1 = SuperSettings::Setting.new(key: "setting_1", value: "1")
      setting_2 = SuperSettings::Setting.new(key: "setting_2", deleted: true)
      setting_3 = SuperSettings::Setting.new(key: "setting_3", value: "3")
      payload = [setting_1, setting_2, setting_3]
      stub_request(:get, "https://example.com/settings/").to_return(body: payload.to_json, headers: {"Content-Type" => "application/json"})
      settings = SuperSettings::Storage::HttpStorage.active_settings
      expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::HttpStorage]
      expect(settings.collect(&:key)).to match_array(["setting_1", "setting_3"])
    end
  end

  describe "updated_since" do
    it "should return settings updated since a timestamp" do
      setting_1 = SuperSettings::Storage::HttpStorage.new(key: "setting_1", raw_value: "1", updated_at: 10.minutes.ago)
      setting_2 = SuperSettings::Storage::HttpStorage.new(key: "setting_2", raw_value: "2", updated_at: 5.minutes.ago)
      setting_3 = SuperSettings::Storage::HttpStorage.new(key: "setting_3", raw_value: "3")
      payload = [setting_2, setting_3]
      time = 6.minutes.ago
      stub_request(:get, "https://example.com/settings/updated_since").with(query: {time: time.to_param}).to_return(body: payload.to_json, headers: {"Content-Type" => "application/json"})
      settings = SuperSettings::Storage::HttpStorage.updated_since(time)
      expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::HttpStorage]
      expect(settings.collect(&:key)).to match_array(["setting_2", "setting_3"])
    end
  end

  describe "find_by_key" do
    it "should return settings updated since a timestamp" do
      setting_1 = SuperSettings::Storage::HttpStorage.new(key: "setting_1", raw_value: "1", updated_at: 10.minutes.ago)
      setting_2 = SuperSettings::Storage::HttpStorage.new(key: "setting_2", raw_value: "2", updated_at: 5.minutes.ago)
      stub_request(:get, "https://example.com/settings/setting").with(query: {key: "setting_1"}).to_return(body: setting_1.to_json, headers: {"Content-Type" => "application/json"})
      stub_request(:get, "https://example.com/settings/setting").with(query: {key: "setting_2"}).to_return(body: setting_2.to_json, headers: {"Content-Type" => "application/json"})
      stub_request(:get, "https://example.com/settings/setting").with(query: {key: "not_exist"}).to_return(status: 404)
      expect(SuperSettings::Storage::HttpStorage.find_by_key("setting_1")).to eq setting_1
      expect(SuperSettings::Storage::HttpStorage.find_by_key("setting_2")).to eq setting_2
      expect(SuperSettings::Storage::HttpStorage.find_by_key("not_exist")).to eq nil
      expect(SuperSettings::Storage::HttpStorage.find_by_key("setting_1").stored?).to eq true
    end
  end

  describe "last_updated_at" do
    it "should return the last time a setting was updated" do
      last_updated_at = Time.at(Time.now.to_i)
      stub_request(:get, "https://example.com/settings/last_updated_at").to_return(body: {last_updated_at: last_updated_at}.to_json, headers: {"Content-Type" => "application/json"})
      expect(SuperSettings::Storage::HttpStorage.last_updated_at).to eq last_updated_at
    end
  end

  describe "attributes" do
    it "should cast all the attributes" do
      setting = SuperSettings::Storage::HttpStorage.new(key: "key", raw_value: "1", value_type: "integer", description: "text", updated_at: Time.now, created_at: 1.minute.ago)
      expect(setting.stored?).to eq false

      payload = {settings: [{key: "key", value: "1", value_type: "integer", description: "text"}]}
      stub_request(:post, "https://example.com/settings/").with(body: payload.to_json).to_return(body: {success: true}.to_json, headers: {"Content-Type" => "application/json"})
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

    it "should handle a store response with errors" do
      setting = SuperSettings::Storage::HttpStorage.new(key: "key", raw_value: "1", value_type: "integer", description: "text", updated_at: Time.now, created_at: 1.minute.ago)
      expect(setting.stored?).to eq false

      payload = {settings: [{key: "key", value: "1", value_type: "integer", description: "text"}]}
      stub_request(:post, "https://example.com/settings/").with(body: payload.to_json).to_return(status: 422, body: {success: false, errors: {key: ["failed"]}}.to_json, headers: {"Content-Type" => "application/json"})
      setting.store!

      expect(setting.stored?).to eq false
      expect(setting.errors[:base]).to eq ["failed"]
    end
  end

  describe "history" do
    it "should fetch the setting history" do
      setting = SuperSettings::Storage::HttpStorage.new(key: "key", raw_value: "1")
      payload = [
        {value: nil, changed_by: "Bob", created_at: 1.minute.ago, deleted: true},
        {value: "2", changed_by: "you", created_at: 2.minutes.ago},
        {value: "1", changed_by: "me", created_at: 3.minutes.ago}
      ]
      stub_request(:get, "https://example.com/settings/setting/history").with(query: {key: "key"}).to_return(body: {histories: payload}.to_json, headers: {"Content-Type" => "application/json"})
      histories = setting.history
      expect(histories.collect(&:value)).to eq [nil, "2", "1"]
      expect(histories.collect(&:deleted?)).to eq [true, false, false]
      expect(histories.collect(&:changed_by)).to eq ["Bob", "you", "me"]

      stub_request(:get, "https://example.com/settings/setting/history").with(query: {key: "key", limit: 1, offset: 1}).to_return(body: {histories: [payload[1]]}.to_json, headers: {"Content-Type" => "application/json"})
      expect(setting.history(limit: 1, offset: 1).collect(&:value)).to eq ["2"]

      stub_request(:get, "https://example.com/settings/setting/history").with(query: {key: "key", limit: 1, offset: 2}).to_return(body: {histories: [payload[2]]}.to_json, headers: {"Content-Type" => "application/json"})
      expect(setting.history(limit: 1, offset: 2).collect(&:value)).to eq ["1"]
    end

    it "should not create history since history is maintained on the source system" do
      setting = SuperSettings::Storage::HttpStorage.new(key: "key", raw_value: "1")
      setting.create_history(value: "2", changed_by: "me", created_at: Time.now)
    end
  end

  describe "redact_history" do
    it "should not do anything since history is maintained on the source system" do
      setting = SuperSettings::Storage::HttpStorage.new(key: "key", raw_value: "1")
      setting.send(:redact_history!)
    end
  end
end
