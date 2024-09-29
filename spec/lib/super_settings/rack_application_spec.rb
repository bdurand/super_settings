# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::RackApplication do
  let(:app) { lambda { |env| [200, {}, ["OK"]] } }
  let(:middleware) do
    SuperSettings::RackApplication.new(app, "/prefix") do
      def current_user(request)
        "user@example.com"
      end
    end
  end

  let!(:setting_1) { SuperSettings::Setting.create!(key: "string", value_type: :string, value: "foobar") }
  let!(:setting_2) { SuperSettings::Setting.create!(key: "integer", value_type: :integer, value: 4) }
  let!(:setting_3) { SuperSettings::Setting.create!(key: "float", value_type: :float, value: 12.5) }
  let!(:setting_4) { SuperSettings::Setting.create!(key: "boolean", value_type: :boolean, value: true) }
  let!(:setting_5) { SuperSettings::Setting.create!(key: "datetime", value_type: :datetime, value: Time.now) }
  let!(:setting_6) { SuperSettings::Setting.create!(key: "array", value_type: :array, value: ["foo", "bar"]) }

  describe "method definition" do
    it "should allow overriding methods in the initialize block" do
      expect(middleware.current_user(Rack::Request.new({}))).to eq "user@example.com"
    end
  end

  describe "pass through" do
    it "should pass through to the app if the prefix doesn't match" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/foo/settings")
      expect(response).to eq [200, {}, ["OK"]]
    end

    it "should pass through to the app if the path doesn't match" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/foo")
      expect(response).to eq [200, {}, ["OK"]]
    end
  end

  describe "root" do
    it "should return the application HTML page" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix")
      expect(response[0]).to eq 200
      expect(response[1]).to match("content-type" => "text/html; charset=utf-8", "cache-control" => "no-cache")
    end

    it "should return a forbidden response if access is denied" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:allow_write?).with(:user).and_return(false)
      allow(SuperSettings).to receive(:authentication_url).and_return(nil)
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix")
      expect(response[0]).to eq 403
    end

    it "should return a redirect if access is denied and a login URL is defined" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:authenticated?).with(:user).and_return(false)
      allow(SuperSettings).to receive(:authentication_url).and_return("https://example.com/login")
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix")
      expect(response[0]).to eq 302
      expect(response[1]["location"]).to eq "https://example.com/login"
    end
  end

  describe "index" do
    it "should have a REST endoint" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/settings")
      expect(response[0]).to eq 200
      expect(response[1]).to match("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
      body = response[2].first
      expect(JSON.parse(body)["settings"]).to eq [setting_6, setting_4, setting_5, setting_3, setting_2, setting_1].collect { |s| JSON.parse(s.to_json) }
    end

    it "renders valid HTML" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/settings")
      html = response[2].first
      doc = Nokogiri::HTML(html)
      expect(doc.errors).to be_empty
    end

    it "should return a forbidden response if access is denied" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:allow_read?).with(:user).and_return(false)
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/settings")
      expect(response[0]).to eq 403
    end
  end

  describe "show" do
    it "should have a REST endoint" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/setting", "QUERY_STRING" => "key=string", "rack.input" => StringIO.new)
      expect(response[0]).to eq 200
      expect(response[1]).to match("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
      body = response[2].first
      expect(JSON.parse(body)).to eq JSON.parse(setting_1.to_json)
    end

    it "should return a forbidden response if access is denied" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:allow_read?).with(:user).and_return(false)
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/setting", "QUERY_STRING" => "key=string", "rack.input" => StringIO.new)
      expect(response[0]).to eq 403
    end
  end

  describe "history" do
    it "should have a REST endoint" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/setting/history", "QUERY_STRING" => "key=string", "rack.input" => StringIO.new)
      expect(response[0]).to eq 200
      expect(response[1]).to match("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
      body = response[2].first
      expect(JSON.parse(body)).to eq({
        "key" => setting_1.key,
        "histories" => setting_1.history(limit: nil, offset: 0).collect do |history|
          JSON.parse({value: history.value, changed_by: history.changed_by_display, created_at: history.created_at}.to_json)
        end
      })
    end

    it "should return a forbidden response if access is denied" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:allow_read?).with(:user).and_return(false)
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/setting/history", "QUERY_STRING" => "key=string", "rack.input" => StringIO.new)
      expect(response[0]).to eq 403
    end
  end

  describe "last_updated_at" do
    it "should have a REST endoint" do
      time = Time.at(Time.now + 10.to_i)
      setting_1.updated_at = time
      setting_1.save!
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/last_updated_at")
      expect(response[0]).to eq 200
      expect(response[1]).to match("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
      body = response[2].first
      expect(JSON.parse(body)).to eq({"last_updated_at" => time.utc.iso8601})
    end

    it "should return a forbidden response if access is denied" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:allow_read?).with(:user).and_return(false)
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/last_updated_at")
      expect(response[0]).to eq 403
    end
  end

  describe "updated_since" do
    it "should have a REST endoint" do
      setting_1.updated_at = Time.now + 20
      setting_1.save!
      setting_2.updated_at = Time.now + 20
      setting_2.save!
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/updated_since", "QUERY_STRING" => "time=#{(Time.now + 10).iso8601}", "rack.input" => StringIO.new)
      expect(response[0]).to eq 200
      expect(response[1]).to match("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
      body = response[2].first
      expect(JSON.parse(body)["settings"]).to match_array([JSON.parse(setting_1.to_json), JSON.parse(setting_2.to_json)])
    end

    it "should return a forbidden response if access is denied" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:allow_read?).with(:user).and_return(false)
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/updated_since")
      expect(response[0]).to eq 403
    end
  end

  describe "update" do
    it "should have a REST endoint" do
      request_body = {
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
      response = middleware.call("REQUEST_METHOD" => "POST", "SCRIPT_NAME" => "/prefix/settings", "CONTENT_TYPE" => "application/json", "rack.input" => StringIO.new(request_body))
      expect(response[0]).to eq 200
      expect(response[1]).to match("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
      body = response[2].first
      expect(JSON.parse(body)).to eq({"success" => true})
      expect(SuperSettings::Setting.find_by_key(setting_1.key).value).to eq "new value"
      expect(SuperSettings::Setting.all.detect { |s| s.key == setting_2.key }.deleted?).to eq true
      expect(SuperSettings::Setting.find_by_key("newkey").value).to eq 44
    end

    it "should not update any settings on the REST endpoint if there is an error" do
      request_body = {
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
      response = middleware.call("REQUEST_METHOD" => "POST", "SCRIPT_NAME" => "/prefix/settings", "CONTENT_TYPE" => "application/json", "rack.input" => StringIO.new(request_body))
      expect(response[0]).to eq 422
      expect(response[1]).to match("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
      body = response[2].first
      expect(JSON.parse(body)).to eq({"success" => false, "errors" => {"integer" => ["value type must be one of string, integer, float, boolean, datetime, array"]}})
      expect(SuperSettings::Setting.find_by_key(setting_1.key).value).to eq "foobar"
      expect(SuperSettings::Setting.find_by_key("newkey")).to eq nil
    end

    it "should return a forbidden response if access is denied" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:allow_write?).with(:user).and_return(false)
      response = middleware.call("REQUEST_METHOD" => "POST", "SCRIPT_NAME" => "/prefix/settings")
      expect(response[0]).to eq 403
    end
  end
end
