# frozen_string_literal: true

require_relative "../spec_helper"

describe SuperSettings::HttpClient do
  let(:payload) { {"a" => 1} }
  let(:response) { {body: JSON.dump(payload), headers: {"content-type" => "application/json"}} }

  describe "get" do
    it "can make get requests" do
      http = SuperSettings::HttpClient.new("https://example.com")
      stub_request(:get, "https://example.com/settings").to_return(response)
      http = SuperSettings::HttpClient.new("https://example.com")
      expect(http.get("/settings")).to eq payload
    end

    it "can add query parameters" do
      http = SuperSettings::HttpClient.new("https://example.com")
      stub_request(:get, "https://example.com/settings").with(query: {foo: "bar"}).to_return(response)
      expect(http.get("/settings", foo: "bar")).to eq payload
    end
  end

  describe "post" do
    it "can make post requests" do
      http = SuperSettings::HttpClient.new("https://example.com")
      stub_request(:post, "https://example.com/settings").to_return(response)
      expect(http.post("/settings")).to eq payload
    end

    it "can post a payload" do
      http = SuperSettings::HttpClient.new("https://example.com")
      stub_request(:post, "https://example.com/settings").with(body: JSON.dump(payload)).to_return(response)
      expect(http.post("/settings", payload)).to eq payload
    end
  end

  describe "path prefix" do
    it "adds the path prefix from the base url to the request" do
      http = SuperSettings::HttpClient.new("https://example.com/api")
      stub_request(:get, "https://example.com/api/settings").to_return(response)
      expect(http.get("/settings")).to eq payload
    end
  end

  describe "headers" do
    it "adds headers to the request" do
      http = SuperSettings::HttpClient.new("https://example.com", headers: {"foo" => "bar"})
      stub_request(:get, "https://example.com/settings").with(headers: {"foo" => "bar"}).to_return(response)
      expect(http.get("/settings")).to eq payload
    end
  end

  describe "query parameters" do
    it "adds query parameters to the request" do
      http = SuperSettings::HttpClient.new("https://example.com", params: {foo: "bar"})
      stub_request(:get, "https://example.com/settings").with(query: {foo: "bar"}).to_return(response)
      expect(http.get("/settings")).to eq payload
    end
  end

  describe "connection pool" do
    it "is thread safe" do
      http = SuperSettings::HttpClient.new("https://example.com")
      stub_request(:get, "https://example.com/settings").to_return(response)
      threads = []
      20.times do
        threads << Thread.new do
          http.get("/settings")
        end
      end
      expect(threads.map(&:value)).to eq Array.new(20, payload)
    end
  end
end
