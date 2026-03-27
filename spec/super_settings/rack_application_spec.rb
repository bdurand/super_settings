# frozen_string_literal: true

require "spec_helper"

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
    around do |example|
      original_color_scheme = SuperSettings.configuration.controller.color_scheme
      original_dark_mode_selector = SuperSettings.configuration.controller.dark_mode_selector
      example.run
      SuperSettings.configuration.controller.color_scheme = original_color_scheme
      SuperSettings.configuration.controller.dark_mode_selector = original_dark_mode_selector
    end

    it "should render the theme toggle when color_scheme is not configured" do
      SuperSettings.configuration.controller.color_scheme = nil
      SuperSettings.configuration.controller.dark_mode_selector = nil
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix")
      expect(response[0]).to eq 200
      expect(response[2].first).to include('id="super-settings-theme-toggle"')
      expect(response[2].first).to include("super_settings_theme")
      expect(response[2].first).to include("[data-theme=dark]")
    end

    it "should not render the theme toggle when color_scheme is explicitly configured" do
      SuperSettings.configuration.controller.color_scheme = :dark
      SuperSettings.configuration.controller.dark_mode_selector = nil
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix")
      expect(response[0]).to eq 200
      expect(response[2].first).not_to include('id="super-settings-theme-toggle"')
    end

    it "should return the application HTML page" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix")
      expect(response[0]).to eq 200
      expect(response[1]).to include("content-type" => "text/html; charset=utf-8", "cache-control" => "no-cache")
    end

    it "should render in read-only mode when allow_write? returns false" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:allow_write?).with(:user).and_return(false)
      allow(SuperSettings).to receive(:authentication_url).and_return(nil)
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix")
      expect(response[0]).to eq 200
      expect(response[2].first).to include('data-read-only="true"')
    end

    it "should render in read-only mode when the env flag is set" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix", "super_settings.read_only" => true)
      expect(response[0]).to eq 200
      expect(response[2].first).to include('data-read-only="true"')
    end

    it "should not include read-only attribute when user has write access" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix")
      expect(response[0]).to eq 200
      expect(response[2].first).to_not match(/<main[^>]*data-read-only/)
    end

    it "should return a forbidden response if read access is denied" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:allow_read?).with(:user).and_return(false)
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

  describe "authorized" do
    it "should return authorized with read-write permission" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/authorized")
      expect(response[0]).to eq 200
      expect(response[1]).to include("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
      expect(response[1]["super-settings-permission"]).to eq "read-write"
      body = JSON.parse(response[2].first)
      expect(body).to eq({"authorized" => true, "permission" => "read-write"})
    end

    it "should return authorized with read-only permission when allow_write? returns false" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:allow_write?).with(:user).and_return(false)
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/authorized")
      expect(response[0]).to eq 200
      expect(response[1]["super-settings-permission"]).to eq "read-only"
      body = JSON.parse(response[2].first)
      expect(body).to eq({"authorized" => true, "permission" => "read-only"})
    end

    it "should return authorized with read-only permission when the env flag is set" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/authorized", "super_settings.read_only" => true)
      expect(response[0]).to eq 200
      expect(response[1]["super-settings-permission"]).to eq "read-only"
      body = JSON.parse(response[2].first)
      expect(body).to eq({"authorized" => true, "permission" => "read-only"})
    end

    it "should return an unauthorized response if the user is not authenticated" do
      allow(middleware).to receive(:current_user).and_return(nil)
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/authorized")
      expect(response[0]).to eq 401
    end

    it "should return a forbidden response if read access is denied" do
      allow(middleware).to receive(:current_user).and_return(:user)
      allow(middleware).to receive(:allow_read?).with(:user).and_return(false)
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/authorized")
      expect(response[0]).to eq 403
    end
  end

  describe "index" do
    it "should have a REST endoint" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/settings")
      expect(response[0]).to eq 200
      expect(response[1]).to include("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
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
      expect(response[1]).to include("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
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
      expect(response[1]).to include("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
      body = response[2].first
      expect(JSON.parse(body)).to eq({
        "key" => setting_1.key,
        "histories" => setting_1.history(limit: nil, offset: 0).collect do |history|
          JSON.parse({value: history.value, changed_by: history.changed_by_display, created_at: history.created_at.utc.iso8601(6)}.to_json)
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
      time = SuperSettings::TimePrecision.new(Time.now + 10).time
      setting_1.updated_at = time
      setting_1.save!
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix/last_updated_at")
      expect(response[0]).to eq 200
      expect(response[1]).to include("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
      body = response[2].first
      expect(JSON.parse(body)).to eq({"last_updated_at" => time.utc.iso8601(6)})
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
      expect(response[1]).to include("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
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
      expect(response[1]).to include("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
      body = response[2].first
      expect(JSON.parse(body)).to eq({"success" => true, "values" => {"string" => "new value", "integer" => nil, "newkey" => 44}})
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
      expect(response[1]).to include("content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache")
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

    it "should return a forbidden response when the env flag is set to read-only" do
      request_body = {settings: [{key: "string", value: "new value", value_type: "string"}]}.to_json
      response = middleware.call("REQUEST_METHOD" => "POST", "SCRIPT_NAME" => "/prefix/settings", "CONTENT_TYPE" => "application/json", "rack.input" => StringIO.new(request_body), "super_settings.read_only" => true)
      expect(response[0]).to eq 403
      expect(SuperSettings::Setting.find_by_key(setting_1.key).value).to eq "foobar"
    end
  end

  describe "locale resolution" do
    it "sets the locale from the lang query parameter" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix", "QUERY_STRING" => "lang=es")
      body = response[2].first
      expect(body).to include('lang="es"')
    end

    it "sets the locale from the super_settings_locale cookie" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix", "HTTP_COOKIE" => "super_settings_locale=fr")
      body = response[2].first
      expect(body).to include('lang="fr"')
    end

    it "sets the locale from the Accept-Language header" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix", "HTTP_ACCEPT_LANGUAGE" => "de-DE,de;q=0.9,en;q=0.8")
      body = response[2].first
      expect(body).to include('lang="de"')
    end

    it "prefers query parameter over cookie and header" do
      response = middleware.call(
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME" => "/prefix",
        "QUERY_STRING" => "lang=ja",
        "HTTP_COOKIE" => "super_settings_locale=fr",
        "HTTP_ACCEPT_LANGUAGE" => "de"
      )
      body = response[2].first
      expect(body).to include('lang="ja"')
    end

    it "prefers cookie over Accept-Language header" do
      response = middleware.call(
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME" => "/prefix",
        "HTTP_COOKIE" => "super_settings_locale=ko",
        "HTTP_ACCEPT_LANGUAGE" => "de"
      )
      body = response[2].first
      expect(body).to include('lang="ko"')
    end

    it "falls back to default locale when no locale is specified" do
      response = middleware.call("REQUEST_METHOD" => "GET", "SCRIPT_NAME" => "/prefix")
      body = response[2].first
      expect(body).to include('lang="en"')
    end
  end
end
