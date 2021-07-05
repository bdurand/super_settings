# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::RestAPI do
  let!(:setting_1) { SuperSettings::Setting.create!(key: "string", value_type: :string, value: "foobar").tap { |object| SuperSettings::Setting.find_by_key(object.key) } }
  let!(:setting_2) { SuperSettings::Setting.create!(key: "integer", value_type: :integer, value: 4).tap { |object| SuperSettings::Setting.find_by_key(object.key) } }
  let!(:setting_3) { SuperSettings::Setting.create!(key: "float", value_type: :float, value: 12.5).tap { |object| SuperSettings::Setting.find_by_key(object.key) } }
  let!(:setting_4) { SuperSettings::Setting.create!(key: "boolean", value_type: :boolean, value: true).tap { |object| SuperSettings::Setting.find_by_key(object.key) } }
  let!(:setting_5) { SuperSettings::Setting.create!(key: "datetime", value_type: :datetime, value: Time.now).tap { |object| SuperSettings::Setting.find_by_key(object.key) } }
  let!(:setting_6) { SuperSettings::Setting.create!(key: "array", value_type: :array, value: ["foo", "bar"]).tap { |object| SuperSettings::Setting.find_by_key(object.key) } }

  before do
    SuperSettings.load_settings
  end

  describe "index" do
    it "should return the settingd" do
      response = SuperSettings::RestAPI.index
      expect(response).to eq [setting_6, setting_4, setting_5, setting_3, setting_2, setting_1].collect(&:as_json)
    end
  end

  describe "show" do
    it "should have a REST endpoint" do
      response = SuperSettings::RestAPI.show(setting_1.key)
      expect(response).to eq setting_1.as_json
    end
  end

  describe "history" do
    it "should have a REST endpoint" do
      response = SuperSettings::RestAPI.history(setting_1.key)
      expect(response).to eq({
        key: setting_1.key,
        histories: setting_1.history(limit: nil, offset: 0).collect do |history|
          {value: history.value, changed_by: history.changed_by_display, created_at: history.created_at}
        end
      })
    end

    it "should include pagination parameters" do
      setting_1.value = "2"
      setting_1.save!
      setting_1.value = "3"
      setting_1.save!
      setting_1.value = "4"
      setting_1.save!
      response = SuperSettings::RestAPI.history(setting_1.key, limit: 2, offset: 1)
      expect(response).to eq({
        key: setting_1.key,
        histories: setting_1.history(limit: 2, offset: 1).collect do |history|
          {value: history.value, changed_by: history.changed_by_display, created_at: history.created_at}
        end,
        previous_page_params: {key: "string", limit: 2, offset: 0},
        next_page_params: {key: "string", limit: 2, offset: 3}
      })
    end
  end

  describe "update" do
    it "should update settings as a REST endpoint" do
      response = SuperSettings::RestAPI.update([
        {
          key: "string",
          value: "new value",
          value_type: "string"
        },
        {
          key: "integer",
          deleted: true
        },
        {
          key: "newkey",
          value: "44",
          value_type: "integer"
        }
      ])
      expect(response).to eq({success: true})
      expect(SuperSettings::Setting.find_by_key(setting_1.key).value).to eq "new value"
      expect(SuperSettings::Setting.all.detect { |s| s.key == setting_2.key }.deleted?).to eq true
      expect(SuperSettings::Setting.find_by_key("newkey").value).to eq 44
    end

    it "should not update any settings on the REST endpoint if there is an error" do
      response = SuperSettings::RestAPI.update([
        {
          key: "string",
          value: "new value",
          value_type: "string"
        },
        {
          key: "newkey",
          value: "44",
          value_type: "integer"
        },
        {
          key: "integer",
          value_type: "invalid"
        }
      ])
      expect(response[:success]).to eq false
      expect(response[:errors]).to eq({"integer" => ["value type must be one of string, integer, float, boolean, datetime, array, secret"]})
      expect(SuperSettings::Setting.find_by_key(setting_1.key).value).to eq "foobar"
      expect(SuperSettings::Setting.find_by_key("newkey")).to eq nil
    end
  end

  describe "last_updated_at" do
    it "should return the timestamp of the last updated setting" do
      time = Time.at(Time.now + 10.to_i)
      setting_1.updated_at = time
      setting_1.save!
      setting_1_key = setting_1.key
      setting_1 = SuperSettings::Setting.find_by_key(setting_1_key)
      response = SuperSettings::RestAPI.last_updated_at
      expect(response).to eq({last_updated_at: time.utc.iso8601})
    end
  end

  describe "updated_since" do
    it "should return settings updated since a given time" do
      setting_1.updated_at = Time.now + 20
      setting_1.save!
      setting_1_key = setting_1.key
      setting_1 = SuperSettings::Setting.find_by_key(setting_1_key)
      setting_2.updated_at = Time.now + 20
      setting_2.save!
      setting_2_key = setting_2.key
      setting_2 = SuperSettings::Setting.find_by_key(setting_2_key)
      response = SuperSettings::RestAPI.updated_since(Time.now + 5)
      expect(response).to match_array([setting_1.as_json, setting_2.as_json])
    end
  end
end
