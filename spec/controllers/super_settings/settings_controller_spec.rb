# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::SettingsController, type: :controller do
  routes { SuperSettings::Engine.routes }

  let!(:setting_1) { SuperSettings::Setting.create!(key: "string", value_type: :string, value: "foobar") }
  let!(:setting_2) { SuperSettings::Setting.create!(key: "integer", value_type: :integer, value: 4) }
  let!(:setting_3) { SuperSettings::Setting.create!(key: "float", value_type: :float, value: 12.5) }
  let!(:setting_4) { SuperSettings::Setting.create!(key: "boolean", value_type: :boolean, value: true) }
  let!(:setting_5) { SuperSettings::Setting.create!(key: "datetime", value_type: :datetime, value: Time.now) }
  let!(:setting_6) { SuperSettings::Setting.create!(key: "array", value_type: :array, value: ["foo", "bar"]) }

  describe "index" do
    it "should show all settings" do
      get :index
      expect(response.status).to eq 200
      expect(response.content_type).to include "text/html"
    end

    it "should have a REST endoint" do
      request.headers["Accept"] = "application/json"
      get :index
      expect(response.status).to eq 200
      expect(response.content_type).to include "application/json"
      expect(JSON.parse(response.body)).to eq [setting_6, setting_4, setting_5, setting_3, setting_2, setting_1].collect { |s| JSON.parse(s.to_json) }
    end
  end

  describe "show" do
    it "should have a REST endpoint" do
      request.headers["Accept"] = "application/json"
      get :show, **request_params(key: setting_1.key)
      expect(response.status).to eq 200
      expect(response.content_type).to include "application/json"
      expect(JSON.parse(response.body)).to eq JSON.parse(setting_1.to_json)
    end
  end

  describe "history" do
    it "should have a REST endpoint" do
      request.headers["Accept"] = "application/json"
      get :history, **request_params(key: setting_1.key)
      expect(response.status).to eq 200
      expect(response.content_type).to include "application/json"
      expect(JSON.parse(response.body)).to eq({
        "key" => setting_1.key,
        "histories" => setting_1.history(limit: 100, offset: 0).collect do |history|
          JSON.parse({value: history.value, changed_by: history.changed_by_display, created_at: history.created_at}.to_json)
        end
      })
    end
  end

  describe "update" do
    it "should update settings from a hash" do
      post :update, **request_params({
        settings: {
          "setting.1" => {
            key: "string",
            value: "new value",
            value_type: "string"
          },
          "setting.2" => {
            key: "integer",
            delete: "1"
          },
          "setting.3" => {
            key: "newkey",
            value: "44",
            value_type: "integer"
          }
        }
      })
      expect(response).to redirect_to(routes.url_for(host: "test.host", controller: "super_settings/settings", action: :index))
      expect(setting_1.reload.value).to eq "new value"
      expect(setting_2.reload.deleted?).to eq true
      expect(SuperSettings::Setting.find_by_key("newkey").value).to eq 44
    end

    it "should not update any settings if there is an error" do
      post :update, **request_params({
        settings: {
          "setting.1" => {
            key: "string",
            value: "new value",
            value_type: "string"
          },
          "newrecord" => {
            key: "newkey",
            value: "44",
            value_type: "integer"
          },
          "setting.2" => {
            key: "integer_setting",
            value_type: "invalid"
          }
        }
      })
      expect(response.status).to eq 422
      expect(setting_1.reload.value).to eq "foobar"
      expect(SuperSettings::Setting.find_by_key("newkey")).to eq nil
    end

    it "should update settings as a REST endpoint" do
      request.headers["Accept"] = "application/json"
      request.headers["Content-Type"] = "application/json"
      post :update, body: {
        settings: [
          {
            key: "string",
            value: "new value",
            value_type: "string"
          },
          {
            key: "integer",
            delete: "1"
          },
          {
            key: "newkey",
            value: "44",
            value_type: "integer"
          }
        ]
      }.to_json
      expect(response.status).to eq 200
      expect(JSON.parse(response.body)).to eq({"success" => true})
      expect(setting_1.reload.value).to eq "new value"
      expect(setting_2.reload.deleted?).to eq true
      expect(SuperSettings::Setting.find_by_key("newkey").value).to eq 44
    end

    it "should not update any settings on the REST endpoint if there is an error" do
      request.headers["Accept"] = "application/json"
      post :update, **request_params(settings: [
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
      expect(response.status).to eq 422
      expect(JSON.parse(response.body)).to eq({"success" => false, "errors" => {"integer" => ["Value type is not included in the list"]}})
      expect(setting_1.reload.value).to eq "foobar"
      expect(SuperSettings::Setting.find_by_key("newkey")).to eq nil
    end
  end
end
