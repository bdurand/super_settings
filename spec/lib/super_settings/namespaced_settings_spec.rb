# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::NamespacedSettings do
  after do
    SuperSettings.cache = nil
  end

  let(:sample_settings) { SuperSettings::NamespacedSettings.new(:sample) }
  let(:other_settings) { SuperSettings::NamespacedSettings.new(:other) }

  describe "all" do
    it "should return all settings" do
      setting_1 = sample_settings.create!(key: "setting.1", value: "foo")
      setting_2 = sample_settings.create!(key: "setting.2", value: "foo", deleted: true)
      setting_3 = sample_settings.create!(key: "setting.3", value: "foo")
      other_settings.create!(key: "setting.4", value: "foo")
      expect(sample_settings.all.collect(&:key)).to match_array(["setting.1", "setting.2", "setting.3"])
    end
  end

  describe "updated_since" do
    it "should return all settings updated since a specified time" do
      setting_1 = sample_settings.create!(key: "setting.1", value: "foo", updated_at: Time.now - 1)
      timestamp = Time.now
      setting_2 = sample_settings.create!(key: "setting.2", value: "foo", deleted: true)
      setting_3 = sample_settings.create!(key: "setting.3", value: "foo")
      other_settings.create!(key: "setting.4", value: "foo")
      expect(sample_settings.updated_since(timestamp).collect(&:key)).to match_array(["setting.2", "setting.3"])
    end
  end

  describe "active" do
    it "should return only the active settings" do
      setting_1 = sample_settings.create!(key: "setting.1", value: "foo")
      setting_2 = sample_settings.create!(key: "setting.2", value: "foo", deleted: true)
      setting_3 = sample_settings.create!(key: "setting.3", value: "foo")
      other_settings.create!(key: "setting.4", value: "foo")
      expect(sample_settings.active.collect(&:key)).to match_array(["setting.1", "setting.3"])
    end
  end

  describe "last_updated_at" do
    it "should get the last updated at timestamp for any record" do
      other_settings.create!(key: "setting.4", value: "foo")
      setting_1 = sample_settings.create!(key: "test1", value: "foobar", updated_at: Time.now - 10)
      expect(sample_settings.last_updated_at).to eq sample_settings.find_by_key(setting_1.key).updated_at
      setting_2 = sample_settings.create!(key: "test2", value: "foobar", updated_at: Time.now - 5)
      expect(sample_settings.last_updated_at).to eq sample_settings.find_by_key(setting_2.key).updated_at
      setting_1.update!(value: "new value")
      expect(sample_settings.last_updated_at).to eq sample_settings.find_by_key(setting_1.key).updated_at
    end

    if defined?(ActiveSupport)
      it "should cache the last updated timestamp" do
        cache = ActiveSupport::Cache::MemoryStore.new
        SuperSettings.cache = cache
        setting = sample_settings.create!(key: "test", value: "foobar", updated_at: Time.now - 10)
        last_updated_at = settings.last_updated_at
        expect(sample_settings.last_updated_at).to eq last_updated_at
        expect(cache.read(sample_settings.send(:last_updated_cache_key))).to eq last_updated_at
      end
    end

    it "should have the last updated handle deleted records" do
      setting_1 = sample_settings.create!(key: "test1", value: "foobar", updated_at: Time.now - 10)
      setting_2 = sample_settings.create!(key: "test2", value: "foobar", updated_at: Time.now - 5)
      setting_1.update!(deleted: true)
      setting_1 = sample_settings.all.detect { |s| s.key == setting_1.key }
      expect(sample_settings.last_updated_at).to eq setting_1.updated_at
    end
  end

  describe "bulk_update" do
    it "should update settings in a batch" do
      setting_1 = sample_settings.create!(key: "string", value_type: :string, value: "foobar")
      setting_2 = sample_settings.create!(key: "integer", value_type: :integer, value: 4)
      setting_3 = sample_settings.create!(key: "other", value_type: :string, value: 4)
      success, settings = sample_settings.bulk_update([
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
          value: 44,
          value_type: "integer"
        }
      ])
      expect(success).to eq true
      expect(settings.size).to eq 3
      expect(settings.all? { |setting| setting.errors.empty? }).to eq true
      expect(settings.all?(&:persisted?)).to eq true
      expect(sample_settings.find_by_key(setting_1.key).value).to eq "new value"
      expect(sample_settings.all.detect { |s| s.key == setting_2.key }.deleted?).to eq true
      expect(sample_settings.find_by_key("newkey").value).to eq 44
    end

    it "should not update any settings if there is an error" do
      setting_1 = sample_settings.create!(key: "string", value_type: :string, value: "foobar")
      setting_2 = sample_settings.create!(key: "integer", value_type: :integer, value: 4)
      setting_3 = sample_settings.create!(key: "other", value_type: :string, value: 4)
      success, settings = sample_settings.bulk_update([
        {
          key: "string",
          value: "new value",
          value_type: "string"
        },
        {
          key: "newkey",
          value: 44,
          value_type: "integer"
        },
        {
          key: "integer",
          value_type: "invalid"
        }
      ])
      expect(success).to eq false
      expect(settings.size).to eq 3
      expect(settings.detect { |setting| setting.key == "integer" }.errors).to_not be_empty
      expect(settings.detect { |setting| setting.key == "newkey" }.persisted?).to eq false
      expect(sample_settings.find_by_key(setting_1.key).value).to eq "foobar"
      expect(sample_settings.find_by_key("newkey")).to eq nil
    end
  end
end
