# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::BooleanParser do
  it "should translate false values" do
    expect(SuperSettings::BooleanParser.cast(false)).to eq false
    expect(SuperSettings::BooleanParser.cast("false")).to eq false
    expect(SuperSettings::BooleanParser.cast(:FALSE)).to eq false
    expect(SuperSettings::BooleanParser.cast("off")).to eq false
    expect(SuperSettings::BooleanParser.cast(:OFF)).to eq false
    expect(SuperSettings::BooleanParser.cast("f")).to eq false
    expect(SuperSettings::BooleanParser.cast(:F)).to eq false
    expect(SuperSettings::BooleanParser.cast(0)).to eq false
    expect(SuperSettings::BooleanParser.cast("0")).to eq false
  end

  it "should cast true values" do
    expect(SuperSettings::BooleanParser.cast(true)).to eq true
    expect(SuperSettings::BooleanParser.cast("true")).to eq true
    expect(SuperSettings::BooleanParser.cast(:TRUE)).to eq true
    expect(SuperSettings::BooleanParser.cast("on")).to eq true
    expect(SuperSettings::BooleanParser.cast(:ON)).to eq true
    expect(SuperSettings::BooleanParser.cast("t")).to eq true
    expect(SuperSettings::BooleanParser.cast(:T)).to eq true
    expect(SuperSettings::BooleanParser.cast(1)).to eq true
    expect(SuperSettings::BooleanParser.cast("1")).to eq true
  end

  it "should cast blank to nil" do
    expect(SuperSettings::BooleanParser.cast(nil)).to eq nil
    expect(SuperSettings::BooleanParser.cast("")).to eq nil
  end
end
