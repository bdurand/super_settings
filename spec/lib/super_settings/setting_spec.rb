# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::Setting do
  after do
    SuperSettings::Setting.cache = nil
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
        setting.reload
        expect(setting.value).to eq nil
      end

      it "should cast the value to a string" do
        setting = SuperSettings::Setting.create!(key: "test", value: :foobar, value_type: :string)
        expect(setting.reload.value).to eq "foobar"
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
        setting.reload
        expect(setting.value).to eq nil
      end

      it "should cast the value to an integer" do
        setting = SuperSettings::Setting.create!(key: "test", value: "123", value_type: :integer)
        expect(setting.reload.value).to eq 123
      end

      it "should not be valid with a non-integer" do
        setting = SuperSettings::Setting.new(key: "test", value: "foo", value_type: :integer)
        expect(setting).not_to be_valid
        expect(setting.errors[:value]).to eq ["must be an integer"]
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
        setting.reload
        expect(setting.value).to eq nil
      end

      it "should cast the value to a float" do
        setting = SuperSettings::Setting.create!(key: "test", value: "12.5", value_type: :float)
        expect(setting.reload.value).to eq 12.5
      end

      it "should not be valid with a non-number" do
        setting = SuperSettings::Setting.new(key: "test", value: "foo", value_type: :float)
        expect(setting).not_to be_valid
        expect(setting.errors[:value]).to eq ["is not a number"]
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
        expect(setting.reload.value).to eq nil
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
        setting.reload
        expect(setting.value).to eq nil
      end

      it "should cast the value to a datetime" do
        setting = SuperSettings::Setting.create!(key: "test", value: "March 12, 2021 13:01 UTC", value_type: :datetime)
        Time.use_zone("America/Chicago") do
          expect(setting.value).to eq Time.utc(2021, 3, 12, 13, 1)
          expect(setting.value.zone).to eq "CST"
        end
      end

      it "should not be valid with a non-date" do
        setting = SuperSettings::Setting.new(key: "test", value: "foo", value_type: :datetime)
        expect(setting).not_to be_valid
        expect(setting.errors[:value].map(&:to_s)).to eq ["is invalid"]
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
        setting.reload
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
  end

  describe "deleted" do
    it "should return a nil value for deleted records" do
      setting = SuperSettings::Setting.new(key: "test", value: "foobar", deleted: true)
      expect(setting.deleted?).to eq true
      expect(setting.value).to eq nil
    end
  end

  describe "last_updated_at" do
    it "should get the last updated at timestamp for any record" do
      setting_1 = SuperSettings::Setting.create!(key: "test1", value: "foobar", updated_at: 10.seconds.ago)
      expect(SuperSettings::Setting.last_updated_at).to eq setting_1.reload.updated_at
      setting_2 = SuperSettings::Setting.create!(key: "test2", value: "foobar", updated_at: 5.seconds.ago)
      expect(SuperSettings::Setting.last_updated_at).to eq setting_2.reload.updated_at
      setting_1.touch
      expect(SuperSettings::Setting.last_updated_at).to eq setting_1.reload.updated_at
    end

    it "should cache the last updated timestamp" do
      cache = ActiveSupport::Cache::MemoryStore.new
      SuperSettings::Setting.cache = cache
      setting = SuperSettings::Setting.create!(key: "test", value: "foobar", updated_at: 10.seconds.ago)
      last_updated_at = SuperSettings::Setting.last_updated_at
      setting.update_column(:updated_at, 5.seconds.ago)
      expect(SuperSettings::Setting.last_updated_at).to eq last_updated_at
      setting.touch
      expect(SuperSettings::Setting.last_updated_at).to eq setting.reload.updated_at
    end

    it "should have the last updated handle deleted records" do
      setting_1 = SuperSettings::Setting.create!(key: "test1", value: "foobar", updated_at: 10.seconds.ago)
      setting_2 = SuperSettings::Setting.create!(key: "test2", value: "foobar", updated_at: 5.seconds.ago)
      setting_1.update!(deleted: true)
      expect(SuperSettings::Setting.last_updated_at).to eq setting_1.reload.updated_at
    end
  end

  describe "as_json" do
    it "should serialize the setting" do
      setting = SuperSettings::Setting.create!(key: "test", value: "foobar", description: "Test")
      expect(setting.as_json).to eq({
        id: setting.id,
        key: setting.key,
        value: setting.value,
        value_type: setting.value_type,
        description: setting.description,
        created_at: setting.created_at,
        updated_at: setting.updated_at
      })
    end
  end

  describe "histories" do
    it "should create a history record for each change in value" do
      setting = SuperSettings::Setting.create!(key: "test", value: "foobar")
      setting.update!(value: "bizbaz")
      setting.update!(description: "test value")
      setting.touch
      setting.update!(value: "newvalue")
      histories = setting.histories.order(id: :desc)
      expect(histories.collect(&:value)).to eq ["newvalue", "bizbaz", "foobar"]
    end

    it "should create a history record when the deleted flag is changed" do
      setting = SuperSettings::Setting.create!(key: "test", value: "foobar")
      setting.update!(value: "bizbaz")
      setting.update!(deleted: true)
      setting.update!(deleted: false)
      histories = setting.histories.order(id: :desc)
      expect(histories.collect(&:value)).to eq ["bizbaz", nil, "bizbaz", "foobar"]
      expect(histories.collect(&:deleted?)).to eq [false, true, false, false]
    end

    it "should create a history record if the key is changed" do
      setting = SuperSettings::Setting.create!(key: "test", value: "foobar")
      setting.update!(key: "newkey")
      expect(SuperSettings::History.where(key: "newkey").collect(&:value)).to eq ["foobar"]
      expect(SuperSettings::History.where(key: "test").collect(&:value)).to eq ["foobar"]
    end

    it "should assign the changed_by attribute to the history record and clear the attribute" do
      setting = SuperSettings::Setting.create!(key: "test", value: "foobar", changed_by: "Joe")
      setting.update!(value: "bizbaz")
      setting.update!(value: "newvalue", changed_by: "John")
      histories = setting.histories.order(id: :desc)
      expect(histories.collect(&:changed_by)).to eq ["John", nil, "Joe"]
    end
  end
end
