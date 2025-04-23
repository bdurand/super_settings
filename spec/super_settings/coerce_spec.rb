# frozen_string_literal: true

require_relative "../spec_helper"

describe SuperSettings::Coerce do
  describe "boolean" do
    it "should translate false values" do
      expect(SuperSettings::Coerce.boolean(false)).to eq false
      expect(SuperSettings::Coerce.boolean("false")).to eq false
      expect(SuperSettings::Coerce.boolean(:FALSE)).to eq false
      expect(SuperSettings::Coerce.boolean("off")).to eq false
      expect(SuperSettings::Coerce.boolean(:OFF)).to eq false
      expect(SuperSettings::Coerce.boolean("f")).to eq false
      expect(SuperSettings::Coerce.boolean(:F)).to eq false
      expect(SuperSettings::Coerce.boolean(0)).to eq false
      expect(SuperSettings::Coerce.boolean("0")).to eq false
      expect(SuperSettings::Coerce.boolean("False")).to eq false
    end

    it "should cast true values" do
      expect(SuperSettings::Coerce.boolean(true)).to eq true
      expect(SuperSettings::Coerce.boolean("true")).to eq true
      expect(SuperSettings::Coerce.boolean(:TRUE)).to eq true
      expect(SuperSettings::Coerce.boolean("on")).to eq true
      expect(SuperSettings::Coerce.boolean(:ON)).to eq true
      expect(SuperSettings::Coerce.boolean("t")).to eq true
      expect(SuperSettings::Coerce.boolean(:T)).to eq true
      expect(SuperSettings::Coerce.boolean(1)).to eq true
      expect(SuperSettings::Coerce.boolean("1")).to eq true
      expect(SuperSettings::Coerce.boolean("True")).to eq true
    end

    it "should cast blank to nil" do
      expect(SuperSettings::Coerce.boolean(nil)).to eq nil
      expect(SuperSettings::Coerce.boolean("")).to eq nil
    end
  end

  describe "time" do
    it "should cast Time values" do
      time = Time.now
      expect(SuperSettings::Coerce.time(time)).to eq time
    end

    it "should cast Date values" do
      date = Date.today
      expect(SuperSettings::Coerce.time(date)).to eq date.to_time
    end

    it "should cast String values" do
      time = Time.at(Time.now.to_i)
      expect(SuperSettings::Coerce.time(time.to_s)).to eq time
    end

    it "should cast Numeric values" do
      time = Time.at(Time.now.to_i)
      expect(SuperSettings::Coerce.time(time.to_f)).to eq time
    end

    it "should cast blank to nil" do
      expect(SuperSettings::Coerce.time(nil)).to eq nil
      expect(SuperSettings::Coerce.time("")).to eq nil
    end
  end

  describe "string" do
    it "should cast String values" do
      expect(SuperSettings::Coerce.string("string")).to eq "string"
    end

    it "should cast blank to nil" do
      expect(SuperSettings::Coerce.string(nil)).to eq nil
      expect(SuperSettings::Coerce.string("")).to eq nil
    end

    it "should cast arrays to multiline strings" do
      expect(SuperSettings::Coerce.string(["a", "b", "c"])).to eq "a\nb\nc"
    end

    it "should cast Time values to ISO8601 strings" do
      time = Time.now
      expect(SuperSettings::Coerce.string(time)).to eq time.iso8601
    end

    it "should cast other values to string" do
      expect(SuperSettings::Coerce.string(1)).to eq "1"
      expect(SuperSettings::Coerce.string(true)).to eq "true"
      expect(SuperSettings::Coerce.string(false)).to eq "false"
    end
  end
end
