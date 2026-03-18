# frozen_string_literal: true

require "spec_helper"

describe SuperSettings::Application do
  it "should render the application HTML" do
    application = SuperSettings::Application.new
    html = application.render
    expect(html).to include("<div")
    expect(html).to_not include("<head")
  end

  it "should render the application HTML with a layout" do
    application = SuperSettings::Application.new(layout: :default)
    html = application.render
    expect(html).to include("<div")
    expect(html).to include("<head")
  end

  it "should render in read-only mode" do
    application = SuperSettings::Application.new(read_only: true)
    html = application.render
    expect(html).to include('data-read-only="true"')
  end

  it "should not include the read-only attribute by default" do
    application = SuperSettings::Application.new
    html = application.render
    expect(html).to_not match(/<main[^>]*data-read-only/)
  end
end
