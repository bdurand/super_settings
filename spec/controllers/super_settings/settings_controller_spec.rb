# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::SettingsController, type: :controller do

  routes { SuperSettings::Engine.routes }

  let!(:setting_1) { SuperSettings::Setting.create!(key: "string", value_type: :string, value: "foobar") }
  let!(:setting_2) { SuperSettings::Setting.create!(key: "integer", value_type: :string, value: 4) }
  let!(:setting_3) { SuperSettings::Setting.create!(key: "float",  value_type: :string, value: 12.5) }
  let!(:setting_4) { SuperSettings::Setting.create!(key: "boolean", value_type: :string, value: true) }
  let!(:setting_5) { SuperSettings::Setting.create!(key: "datetime", value_type: :string, value: Time.now) }
  let!(:setting_6) { SuperSettings::Setting.create!(key: "array", value_type: :string, value: ["foo", "bar"]) }

  describe "index" do
    it "should show all settings" do
      get :index
      expect(response.status).to eq 200
      expect(response.content_type).to eq "text/html; charset=utf-8"
    end

    it "should have a REST endoint" do
      request.headers["Accept"] = "application/json"
      get :index
      expect(response.status).to eq 200
      expect(response.content_type).to eq "application/json; charset=utf-8"
      expect(JSON.parse(response.body)).to eq [setting_6, setting_4, setting_5, setting_3, setting_2, setting_1].collect { |s| JSON.parse(s.to_json) }
    end
  end

  describe "show" do
    it "should show a single setting" do
      get :show, params: {id: setting_1.id.to_s}
      expect(response.status).to eq 200
      expect(response.content_type).to eq "text/html; charset=utf-8"
    end

    it "should have a REST endpoint" do
      request.headers["Accept"] = "application/json"
      get :show, params: {id: setting_1.id.to_s}
      expect(response.status).to eq 200
      expect(response.content_type).to eq "application/json; charset=utf-8"
      expect(JSON.parse(response.body)).to eq JSON.parse(setting_1.to_json)
    end
  end

  describe "history" do
    it "should show setting's history" do
      get :history, params: {id: setting_1.id.to_s}
      expect(response.status).to eq 200
      expect(response.content_type).to eq "text/html; charset=utf-8"
    end

    it "should have a REST endpoint" do
      request.headers["Accept"] = "application/json"
      get :history, params: {id: setting_1.id.to_s}
      expect(response.status).to eq 200
      expect(response.content_type).to eq "application/json; charset=utf-8"
      expect(JSON.parse(response.body)).to eq setting_1.histories.collect { |s| JSON.parse(s.to_json) }
    end
  end

  describe "edit" do
    it "should load a form to edit a setting" do
      get :edit, params: {id: setting_1.id.to_s}
      expect(response.status).to eq 200
    end
  end

  describe "new" do
    it "should load a form to create a setting" do
      get :new, params: {id: setting_1.id.to_s}
      expect(response.status).to eq 200
    end
  end

  describe "update" do
    it "should update settings" do
      post :update, params: {settings: {
        setting_1.id.to_s => {
          key: "string",
          value: "new value",
          value_type: "string"
        },
        setting_2.id.to_s => {
          key: "integer",
          _delete: "1"
        },
        "newrecord" => {
          key: "newkey",
          value: "44",
          value_type: "integer"
        }
      }}
      expect(response).to redirect_to(routes.url_helpers.index_path)
      expect(setting_1.reload.value).to eq "new value"
      expect(setting_2.reload.deleted?).to eq true
      expect(SuperSettings::Setting.find_by(key: "newkey").value).to eq 44
    end

    it "should not update any settings if there is an error" do
      post :update, params: {settings: {
        setting_1.id.to_s => {
          key: "string",
          value: "new value",
          value_type: "string"
        },
        "newrecord" => {
          key: "newkey",
          value: "44",
          value_type: "integer"
        },
        setting_2.id.to_s => {
          key: "integer",
          value_type: "invalid"
        },
      }}
      expect(response.status).to eq 422
      expect(setting_1.reload.value).to eq "foobar"
      expect(SuperSettings::Setting.find_by(key: "newkey")).to eq nil
    end
  end
end
