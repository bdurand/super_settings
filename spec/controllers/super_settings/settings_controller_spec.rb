# frozen_string_literal: true

require_relative "../../spec_helper"

if defined?(SuperSettings::SettingsController)
  describe SuperSettings::SettingsController, type: :controller do
    routes { SuperSettings::Engine.routes }

    let!(:setting_1) { SuperSettings::Setting.create!(key: "string", value_type: :string, value: "foobar") }
    let!(:setting_2) { SuperSettings::Setting.create!(key: "integer", value_type: :integer, value: 4) }
    let!(:setting_3) { SuperSettings::Setting.create!(key: "float", value_type: :float, value: 12.5) }
    let!(:setting_4) { SuperSettings::Setting.create!(key: "boolean", value_type: :boolean, value: true) }
    let!(:setting_5) { SuperSettings::Setting.create!(key: "datetime", value_type: :datetime, value: Time.now) }
    let!(:setting_6) { SuperSettings::Setting.create!(key: "array", value_type: :array, value: ["foo", "bar"]) }

    describe "root" do
      it "should show the single page application" do
        get :root
        expect(response.status).to eq 200
        expect(response.content_type).to include "text/html"
      end
    end

    describe "index" do
      it "should have a REST endoint" do
        request.headers["Accept"] = "application/json"
        get :index
        expect(response.status).to eq 200
        expect(response.content_type).to include "application/json"
        expect(JSON.parse(response.body)["settings"]).to eq [setting_6, setting_4, setting_5, setting_3, setting_2, setting_1].collect { |s| JSON.parse(s.to_json) }
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
          "histories" => setting_1.history(limit: nil, offset: 0).collect do |history|
            JSON.parse({value: history.value, changed_by: history.changed_by_display, created_at: history.created_at}.to_json)
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
        request.headers["Accept"] = "application/json"
        get :history, **request_params(key: setting_1.key, limit: 2, offset: 1)
        expect(response.status).to eq 200
        expect(response.content_type).to include "application/json"
        expect(JSON.parse(response.body)).to eq({
          "key" => setting_1.key,
          "histories" => setting_1.history(limit: 2, offset: 1).collect do |history|
            JSON.parse({value: history.value, changed_by: history.changed_by_display, created_at: history.created_at}.to_json)
          end,
          "previous_page_params" => {"key" => "string", "limit" => 2, "offset" => 0},
          "next_page_params" => {"key" => "string", "limit" => 2, "offset" => 3}
        })
      end
    end

    describe "update" do
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
              deleted: true
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
        expect(SuperSettings::Setting.find_by_key(setting_1.key).value).to eq "new value"
        expect(SuperSettings::Setting.all.detect { |s| s.key == setting_2.key }.deleted?).to eq true
        expect(SuperSettings::Setting.find_by_key("newkey").value).to eq 44
      end

      it "should not update any settings on the REST endpoint if there is an error" do
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
              key: "newkey",
              value: "44",
              value_type: "integer"
            },
            {
              key: "integer",
              value_type: "invalid"
            }
          ]
        }.to_json
        expect(response.status).to eq 422
        expect(JSON.parse(response.body)).to eq({"success" => false, "errors" => {"integer" => ["value type must be one of string, integer, float, boolean, datetime, array, secret"]}})
        expect(SuperSettings::Setting.find_by_key(setting_1.key).value).to eq "foobar"
        expect(SuperSettings::Setting.find_by_key("newkey")).to eq nil
      end
    end

    describe "last_updated_at" do
      it "should return the timestamp of the last updated setting" do
        request.headers["Accept"] = "application/json"
        time = Time.at(Time.now + 10.to_i)
        setting_1.updated_at = time
        setting_1.save!
        get :last_updated_at
        expect(response.status).to eq 200
        expect(response.content_type).to include "application/json"
        expect(JSON.parse(response.body)).to eq({"last_updated_at" => time.utc.iso8601})
      end
    end

    describe "updated_since" do
      it "should return settings updated since a given time" do
        request.headers["Accept"] = "application/json"
        setting_1.updated_at = Time.now + 20
        setting_1.save!
        setting_2.updated_at = Time.now + 20
        setting_2.save!
        get :updated_since, **request_params(time: Time.now + 10)
        expect(response.status).to eq 200
        expect(response.content_type).to include "application/json"
        expect(JSON.parse(response.body)["settings"]).to match_array([JSON.parse(setting_1.to_json), JSON.parse(setting_2.to_json)])
      end
    end
  end
end
