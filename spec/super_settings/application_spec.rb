# frozen_string_literal: true

require_relative "../spec_helper"

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
end
