# frozen_string_literal: true

require_relative "../spec_helper"

describe SuperSettings::TimePrecision do
  it "should return a UTC time with microsecond precision" do
    time = SuperSettings::TimePrecision.new(1728485976.123456, :microsecond).time
    expect(time.usec).to eq 123456
    expect(time.to_i).to eq 1728485976
    expect(time.zone).to eq "UTC"
  end

  it "should round up the time after the microsecond" do
    expect(SuperSettings::TimePrecision.new(1728485976.123499, :microsecond).time.usec).to eq 123499
    expect(SuperSettings::TimePrecision.new(1728485976.1234559, :microsecond).time.usec).to eq 123456
    expect(SuperSettings::TimePrecision.new(1728485976.1234561, :microsecond).time.usec).to eq 123456
  end

  it "should return a UTC time with millisecond precision" do
    time = SuperSettings::TimePrecision.new(1728485976.123456, :millisecond).time
    expect(time.usec).to eq 123000
    expect(time.to_i).to eq 1728485976
    expect(time.zone).to eq "UTC"
  end

  it "should return milliseconds after rounding up the microseconds" do
    expect(SuperSettings::TimePrecision.new(1728485976.123499, :millisecond).time.usec).to eq 123000
    expect(SuperSettings::TimePrecision.new(1728485976.1239999, :millisecond).time.usec).to eq 124000
    expect(SuperSettings::TimePrecision.new(1728485976.1239991, :millisecond).time.usec).to eq 123000
  end
end
