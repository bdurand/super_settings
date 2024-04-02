# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::Setting do
  let(:namespace) { "sample" }
  let(:settings) { SuperSettings::NamespacedSettings.new(namespace) }

  after do
    SuperSettings.cache = nil
  end

  describe "value type" do
    describe "string" do
      it "should identify as a string" do
        setting = SuperSettings::Setting.new(key: "test", value_type: :string)
        expect(setting.string?).to eq true
        expect(setting.integer?).to eq false
        expect(setting.float?).to eq false
        expect(setting.boolean?).to eq false
        expect(setting.datetime?).to eq false
        expect(setting.array?).to eq false
      end

      it "should use nil for blank values" do
        setting = SuperSettings::Setting.new(key: "test", value_type: :string)
        expect(setting.value).to eq nil
        setting.value = ""
        setting.save!
        expect(setting.value).to eq nil
      end

      it "should cast the value to a string" do
        setting = SuperSettings::Setting.create!(key: "test", value: :foobar, value_type: :string, namespace: namespace)
        expect(settings.find_by_key(setting.key).value).to eq "foobar"
      end
    end

    describe "integer" do
      it "should identify as an integer" do
        setting = SuperSettings::Setting.new(key: "test", value_type: :integer)
        expect(setting.string?).to eq false
        expect(setting.integer?).to eq true
        expect(setting.float?).to eq false
        expect(setting.boolean?).to eq false
        expect(setting.datetime?).to eq false
        expect(setting.array?).to eq false
      end

      it "should use nil for blank values" do
        setting = SuperSettings::Setting.new(key: "test", value_type: :integer)
        expect(setting.value).to eq nil
        setting.value = ""
        setting.save!
        expect(setting.value).to eq nil
      end

      it "should cast the value to an integer" do
        setting = SuperSettings::Setting.create!(key: "test", value: "123", value_type: :integer, namespace: namespace)
        expect(settings.find_by_key(setting.key).value).to eq 123
      end

      it "should not be valid with a non-integer" do
        setting = SuperSettings::Setting.new(key: "test", value: "foo", value_type: :integer, namespace: namespace)
        expect(setting).not_to be_valid
        expect(setting.errors["value"]).to eq ["value must be an integer"]
      end
    end

    describe "float" do
      it "should identify as a float" do
        setting = SuperSettings::Setting.new(key: "test", value_type: :float)
        expect(setting.string?).to eq false
        expect(setting.integer?).to eq false
        expect(setting.float?).to eq true
        expect(setting.boolean?).to eq false
        expect(setting.datetime?).to eq false
        expect(setting.array?).to eq false
      end

      it "should use nil for blank values" do
        setting = SuperSettings::Setting.new(key: "test", value_type: :float)
        expect(setting.value).to eq nil
        setting.value = ""
        setting.save!
        expect(setting.value).to eq nil
      end

      it "should cast the value to a float" do
        setting = SuperSettings::Setting.create!(key: "test", value: "12.5", value_type: :float, namespace: namespace)
        expect(settings.find_by_key(setting.key).value).to eq 12.5
      end

      it "should not be valid with a non-number" do
        setting = SuperSettings::Setting.new(key: "test", value: "foo", value_type: :float)
        expect(setting).not_to be_valid
        expect(setting.errors["value"]).to eq ["value must be a number"]
      end
    end

    describe "boolean" do
      it "should identify as a boolean" do
        setting = SuperSettings::Setting.new(key: "test", value_type: :boolean)
        expect(setting.string?).to eq false
        expect(setting.integer?).to eq false
        expect(setting.float?).to eq false
        expect(setting.boolean?).to eq true
        expect(setting.datetime?).to eq false
        expect(setting.array?).to eq false
      end

      it "should cast the value to a boolean" do
        setting = SuperSettings::Setting.create!(key: "test", value: nil, value_type: :boolean)
        expect(setting.value).to eq nil
        setting.value = "1"
        expect(setting.value).to eq true
        setting.value = "0"
        expect(setting.value).to eq false
        setting.value = "true"
        expect(setting.value).to eq true
        setting.value = "false"
        expect(setting.value).to eq false
        setting.value = "on"
        expect(setting.value).to eq true
        setting.value = "off"
        expect(setting.value).to eq false
        setting.value = "foo"
        expect(setting.value).to eq true
      end
    end

    describe "datetime" do
      it "should identify as a datetime" do
        setting = SuperSettings::Setting.new(key: "test", value_type: :datetime)
        expect(setting.string?).to eq false
        expect(setting.integer?).to eq false
        expect(setting.float?).to eq false
        expect(setting.boolean?).to eq false
        expect(setting.datetime?).to eq true
        expect(setting.array?).to eq false
      end

      it "should use nil for blank values" do
        setting = SuperSettings::Setting.new(key: "test", value_type: :datetime)
        expect(setting.value).to eq nil
        setting.value = ""
        setting.save!
        expect(setting.value).to eq nil
      end

      it "should cast the value to a datetime" do
        setting = SuperSettings::Setting.create!(key: "test", value: "March 12, 2021 13:01 UTC", value_type: :datetime)
        expect(setting.value.to_i).to eq Time.utc(2021, 3, 12, 13, 1).to_i
      end

      it "should not be valid with a non-date" do
        setting = SuperSettings::Setting.new(key: "test", value: "foo", value_type: :datetime)
        expect(setting).not_to be_valid
        expect(setting.errors["value"].map(&:to_s)).to eq ["value is not a valid datetime"]
      end
    end

    describe "array" do
      it "should identify as an array" do
        setting = SuperSettings::Setting.new(key: "test", value_type: :array)
        expect(setting.string?).to eq false
        expect(setting.integer?).to eq false
        expect(setting.float?).to eq false
        expect(setting.boolean?).to eq false
        expect(setting.datetime?).to eq false
        expect(setting.array?).to eq true
      end

      it "should use nil for blank values" do
        setting = SuperSettings::Setting.new(key: "test", value_type: :array)
        expect(setting.value).to eq nil
        setting.value = ""
        setting.save!
        expect(setting.value).to eq nil
      end

      it "should cast the value to an array" do
        setting = SuperSettings::Setting.create!(key: "test", value: "foo\nbar", value_type: :array)
        expect(setting.value).to eq ["foo", "bar"]
      end

      it "should be able to be set with an array" do
        setting = SuperSettings::Setting.create!(key: "test", value: ["foo", "bar"], value_type: :array)
        expect(setting.value).to eq ["foo", "bar"]
      end
    end

    it "should determine the correct value type based on a value" do
      expect(SuperSettings::Setting.value_type("foo")).to eq "string"
      expect(SuperSettings::Setting.value_type(:foo)).to eq "string"
      expect(SuperSettings::Setting.value_type(nil)).to eq "string"
      expect(SuperSettings::Setting.value_type("1")).to eq "string"
      expect(SuperSettings::Setting.value_type(1)).to eq "integer"
      expect(SuperSettings::Setting.value_type(1.0)).to eq "float"
      expect(SuperSettings::Setting.value_type(true)).to eq "boolean"
      expect(SuperSettings::Setting.value_type(false)).to eq "boolean"
      expect(SuperSettings::Setting.value_type(["foo"])).to eq "array"
      expect(SuperSettings::Setting.value_type(Time.now)).to eq "datetime"
      expect(SuperSettings::Setting.value_type(DateTime.now)).to eq "datetime"
      expect(SuperSettings::Setting.value_type(Date.today)).to eq "datetime"
    end
  end

  describe "deleted" do
    it "should return a nil value for deleted records" do
      setting = SuperSettings::Setting.new(key: "test", value: "foobar", deleted: true)
      expect(setting.deleted?).to eq true
      expect(setting.value).to eq nil
    end
  end

  describe "as_json" do
    it "should serialize the setting" do
      setting = SuperSettings::Setting.create!(key: "test", value: "foobar", description: "Test")
      expect(setting.as_json).to eq({
        key: setting.key,
        value: setting.value,
        value_type: setting.value_type,
        description: setting.description,
        created_at: setting.created_at,
        updated_at: setting.updated_at
      })
    end
  end

  describe "save!" do
    it "should raise an error if the record is not valid" do
      setting = SuperSettings::Setting.new
      expect { setting.save! }.to raise_error(SuperSettings::Setting::InvalidRecordError)
    end

    it "should call the after_save hooks" do
      FakeLogger.instance.messages.clear
      setting = SuperSettings::Setting.new(key: "foo", value: "bar")
      setting.save!
      expect(FakeLogger.instance.messages).to include({key: [nil, "foo"], value: [nil, "bar"]})
    end
  end

  describe "changes" do
    it "gets the changes for the record and clears them after the record is saved" do
      setting = SuperSettings::Setting.new(key: "test", value: "foobar")
      expect(setting.changes.slice("key", "raw_value", "description")).to eq({"key" => [nil, "test"], "raw_value" => [nil, "foobar"]})
      setting.value = "bizbaz"
      expect(setting.changes.slice("key", "raw_value", "description")).to eq({"key" => [nil, "test"], "raw_value" => [nil, "bizbaz"]})
      setting.save!
      expect(setting.changes).to eq({})
      setting.value = "newvalue"
      expect(setting.changes.slice("key", "raw_value", "description")).to eq({"raw_value" => ["bizbaz", "newvalue"]})
    end
  end

  describe "histories" do
    it "should create a history record for each change in value" do
      setting = SuperSettings::Setting.create!(key: "test", value: "foobar")
      setting.update!(value: "bizbaz")
      setting.update!(description: "test value")
      setting.update!(value: "newvalue")
      histories = setting.history(limit: 10)
      expect(histories.collect(&:value)).to eq ["newvalue", "bizbaz", "foobar"]
    end

    it "should create a history record when the deleted flag is changed" do
      setting = SuperSettings::Setting.create!(key: "test", value: "foobar")
      setting.update!(value: "bizbaz")
      setting.update!(deleted: true)
      setting.update!(deleted: false)
      histories = setting.history(limit: 10)
      expect(histories.collect(&:value)).to eq ["bizbaz", nil, "bizbaz", "foobar"]
      expect(histories.collect(&:deleted?)).to eq [false, true, false, false]
    end

    it "should create a history record if the key is changed" do
      setting = SuperSettings::Setting.create!(key: "test", value: "foobar")
      setting.update!(key: "newkey")
      histories = setting.history(limit: 10)
      expect(histories.collect(&:value)).to eq ["foobar"]
    end

    it "should assign the changed_by attribute to the history record and clear the attribute" do
      setting = SuperSettings::Setting.create!(key: "test", value: "foobar", changed_by: "Joe")
      setting.update!(value: "bizbaz")
      setting.update!(value: "newvalue", changed_by: "John")
      histories = setting.history(limit: 10)
      expect(histories.collect(&:changed_by)).to eq ["John", nil, "Joe"]
    end
  end

  describe "set" do
    it "should be able to set a value" do
      SuperSettings.set("foo", "bar")
      expect(SuperSettings.get("foo")).to eq "bar"
    end

    it "should be able to temporarily set a value in a block" do
      SuperSettings.set("foo", "bar") do
        expect(SuperSettings.get("foo")).to eq "bar"
        SuperSettings.set("foo", "boo") do
          expect(SuperSettings.get("foo")).to eq "boo"
        end
        expect(SuperSettings.get("foo")).to eq "bar"
      end
      expect(SuperSettings.get("foo")).to eq nil
    end
  end
end
