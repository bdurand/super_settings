# frozen_string_literal: true

require_relative "../spec_helper"

describe SuperSettings::Setting do
  storage_engines = [SuperSettings::Storage::TestStorage] + EXTENSIONS.values
  if ENV["TEST_STORAGE"].to_s != ""
    storage_engines = [EXTENSIONS[ENV["TEST_STORAGE"].to_sym]]
  end
  storage_engines.each do |storage|
    context "with #{storage}" do
      before(:all) do
        SuperSettings::Setting.storage = storage
      end

      after(:all) do
        SuperSettings::Setting.storage = SuperSettings::Storage::TestStorage
      end

      before do
        SuperSettings::Setting.storage
      end

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
            expect(setting.value).to eq nil
          end

          it "should cast the value to a string" do
            setting = SuperSettings::Setting.create!(key: "test", value: :foobar, value_type: :string)
            expect(SuperSettings::Setting.find_by_key(setting.key).value).to eq "foobar"
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
            setting = SuperSettings::Setting.create!(key: "test", value: "123", value_type: :integer)
            expect(SuperSettings::Setting.find_by_key(setting.key).value).to eq 123
          end

          it "should not be valid with a non-integer" do
            setting = SuperSettings::Setting.new(key: "test", value: "foo", value_type: :integer)
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
            setting = SuperSettings::Setting.create!(key: "test", value: "12.5", value_type: :float)
            expect(SuperSettings::Setting.find_by_key(setting.key).value).to eq 12.5
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

      describe "all" do
        it "should return all settings" do
          setting_1 = SuperSettings::Setting.create!(key: "setting.1", value: "foo")
          setting_2 = SuperSettings::Setting.create!(key: "setting.2", value: "foo", deleted: true)
          setting_3 = SuperSettings::Setting.create!(key: "setting.3", value: "foo")
          expect(SuperSettings::Setting.all.collect(&:key)).to match_array(["setting.1", "setting.2", "setting.3"])
        end
      end

      describe "updated_since" do
        it "should return all settings updated since a specified time" do
          setting_1 = SuperSettings::Setting.create!(key: "setting.1", value: "foo", updated_at: Time.now - 1)
          setting_2 = SuperSettings::Setting.create!(key: "setting.2", value: "foo", deleted: true)
          setting_3 = SuperSettings::Setting.create!(key: "setting.3", value: "foo")
          expect(SuperSettings::Setting.updated_since(setting_1.updated_at).collect(&:key)).to match_array(["setting.2", "setting.3"])
        end
      end

      describe "active" do
        it "should return only the active settings" do
          setting_1 = SuperSettings::Setting.create!(key: "setting.1", value: "foo")
          setting_2 = SuperSettings::Setting.create!(key: "setting.2", value: "foo", deleted: true)
          setting_3 = SuperSettings::Setting.create!(key: "setting.3", value: "foo")
          expect(SuperSettings::Setting.active.collect(&:key)).to match_array(["setting.1", "setting.3"])
        end
      end

      describe "last_updated_at" do
        it "should get the last updated at timestamp for any record" do
          setting_1 = SuperSettings::Setting.create!(key: "test1", value: "foobar", updated_at: Time.now - 10)
          setting_1 = SuperSettings::Setting.find_by_key(setting_1.key)
          expect(SuperSettings::Setting.last_updated_at).to be >= setting_1.updated_at

          setting_2 = SuperSettings::Setting.create!(key: "test2", value: "foobar", updated_at: Time.now - 5)
          setting_2 = SuperSettings::Setting.find_by_key(setting_2.key)
          expect(setting_2.updated_at).to be >= setting_1.updated_at
          expect(SuperSettings::Setting.last_updated_at).to be >= setting_2.updated_at

          setting_1.update!(value: "new value")
          setting_1 = SuperSettings::Setting.find_by_key(setting_1.key)
          expect(setting_1.updated_at).to be >= setting_2.updated_at
          expect(SuperSettings::Setting.last_updated_at).to be >= setting_1.updated_at
        end

        if defined?(ActiveSupport)
          it "should cache the last updated timestamp" do
            cache = ActiveSupport::Cache::MemoryStore.new
            SuperSettings::Setting.cache = cache
            setting = SuperSettings::Setting.create!(key: "test", value: "foobar", updated_at: Time.now - 10)
            last_updated_at = SuperSettings::Setting.last_updated_at
            expect(SuperSettings::Setting.last_updated_at).to eq last_updated_at
            expect(cache.read(SuperSettings::Setting::LAST_UPDATED_CACHE_KEY)).to eq last_updated_at
          end
        end

        it "should have the last updated handle deleted records" do
          setting_1 = SuperSettings::Setting.create!(key: "test1", value: "foobar", updated_at: Time.now - 10)
          setting_2 = SuperSettings::Setting.create!(key: "test2", value: "foobar", updated_at: Time.now - 5)
          t = Time.at(Time.now.to_i)
          setting_1.update!(deleted: true)
          setting_1 = SuperSettings::Setting.all.detect { |s| s.key == setting_1.key }
          expect(SuperSettings::Setting.last_updated_at).to be >= t
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
            created_at: setting.created_at.utc.iso8601(6),
            updated_at: setting.updated_at.utc.iso8601(6)
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

        it "should not call the after_save hooks if the record could not be saved" do
          FakeLogger.instance.messages.clear
          setting = SuperSettings::Setting.new(key: "foo", value: "bar")
          setting.key = nil
          expect { setting.save! }.to raise_error(SuperSettings::Setting::InvalidRecordError)
          expect(FakeLogger.instance.messages).to eq []
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

      describe "value_changed?" do
        it "should return true if the value has changed" do
          setting = SuperSettings::Setting.create!(key: "test", value: "foobar")
          expect(setting.value_changed?).to eq false
          setting.value = "bizbaz"
          expect(setting.value_changed?).to eq true
        end

        it "should return true if the key has changed" do
          setting = SuperSettings::Setting.create!(key: "test", value: "foobar")
          expect(setting.value_changed?).to eq false
          setting.key = "newkey"
          expect(setting.value_changed?).to eq true
        end

        it "should return true if the setting is deleted" do
          setting = SuperSettings::Setting.create!(key: "test", value: "foobar")
          expect(setting.value_changed?).to eq false
          setting.deleted = true
          expect(setting.value_changed?).to eq true
        end

        it "should return true if the setting is undeleted" do
          setting = SuperSettings::Setting.create!(key: "test", value: "foobar", deleted: true)
          expect(setting.value_changed?).to eq false
          setting.deleted = false
          expect(setting.value_changed?).to eq true
        end

        it "should return true if only the type or description is changed" do
          setting = SuperSettings::Setting.create!(key: "test", value: "foobar")
          setting.value_type = :integer
          expect(setting.value_changed?).to eq false
          setting.description = "test"
          expect(setting.value_changed?).to eq false
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

        it "when a record key is changed to an existing key, the history on both records should be updated" do
          SuperSettings::Setting.create!(key: "key", value: "value", changed_by: "Joe")
          setting_1 = SuperSettings::Setting.create!(key: "other", value: "other value", changed_by: "Jim")
          setting_1.update!(key: "key", changed_by: "Sally")
          setting_2 = SuperSettings::Setting.create!(key: "other", value: "new value", changed_by: "Harold")

          setting_1_history = setting_1.history.collect { |h| [h.key, h.value, h.deleted?, h.changed_by] }
          setting_2_history = setting_2.history.collect { |h| [h.key, h.value, h.deleted?, h.changed_by] }

          expect(setting_1_history).to eq [["key", "other value", false, "Sally"], ["key", "value", false, "Joe"]]
          expect(setting_2_history).to eq [["other", "new value", false, "Harold"], ["other", nil, true, "Sally"], ["other", "other value", false, "Jim"]]
        end
      end

      describe "bulk_update" do
        it "should update settings in a batch" do
          setting_1 = SuperSettings::Setting.create!(key: "string", value_type: :string, value: "foobar")
          setting_2 = SuperSettings::Setting.create!(key: "integer", value_type: :integer, value: 4)
          setting_3 = SuperSettings::Setting.create!(key: "other", value_type: :string, value: 4)
          success, settings = SuperSettings::Setting.bulk_update([
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
          expect(SuperSettings::Setting.find_by_key(setting_1.key).value).to eq "new value"
          expect(SuperSettings::Setting.all.detect { |s| s.key == setting_2.key }.deleted?).to eq true
          expect(SuperSettings::Setting.find_by_key("newkey").value).to eq 44
        end

        it "should not update any settings if there is an error" do
          setting_1 = SuperSettings::Setting.create!(key: "string", value_type: :string, value: "foobar")
          setting_2 = SuperSettings::Setting.create!(key: "integer", value_type: :integer, value: 4)
          setting_3 = SuperSettings::Setting.create!(key: "other", value_type: :string, value: 4)
          success, settings = SuperSettings::Setting.bulk_update([
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
          expect(SuperSettings::Setting.find_by_key(setting_1.key).value).to eq "foobar"
          expect(SuperSettings::Setting.find_by_key("newkey")).to eq nil
        end

        it "should create a new setting and delete the old one if the key changed" do
          setting = SuperSettings::Setting.create!(key: "old_key", value_type: :string, value: "old value")
          success, settings = SuperSettings::Setting.bulk_update([
            {
              key: "new_key",
              key_was: "old_key",
              value: "new value",
              value_type: "string"
            }
          ])
          expect(success).to eq true
          expect(settings.size).to eq 2
          expect(settings.all? { |setting| setting.errors.empty? }).to eq true
          expect(settings.all?(&:persisted?)).to eq true
          new_key = SuperSettings::Setting.find_by_key("new_key")
          old_key = SuperSettings::Setting.all.detect { |s| s.key == "old_key" }
          expect(new_key.value).to eq "new value"
          expect(new_key.deleted).to be(false)
          expect(old_key.deleted).to be(true)
        end

        it "should create a new setting and not delete the old one if the key was already updated" do
          setting = SuperSettings::Setting.create!(key: "old_key", value_type: :string, value: "foobar")
          success, settings = SuperSettings::Setting.bulk_update([
            {
              key: "old_key",
              value: "new old value",
              value_type: "string"
            },
            {
              key: "new_key",
              key_was: "old_key",
              value: "new value",
              value_type: "string"
            }
          ])
          expect(success).to eq true
          expect(settings.size).to eq 2
          expect(settings.all? { |setting| setting.errors.empty? }).to eq true
          expect(settings.all?(&:persisted?)).to eq true
          new_key = SuperSettings::Setting.find_by_key("new_key")
          old_key = SuperSettings::Setting.find_by_key("old_key")
          expect(new_key.value).to eq "new value"
          expect(new_key.deleted).to be(false)
          expect(old_key.value).to eq "new old value"
          expect(old_key.deleted).to be(false)
        end

        it "should create a new setting and not delete the old one if the key will be updated" do
          setting = SuperSettings::Setting.create!(key: "old_key", value_type: :string, value: "foobar")
          success, settings = SuperSettings::Setting.bulk_update([
            {
              key: "new_key",
              key_was: "old_key",
              value: "new value",
              value_type: "string"
            },
            {
              key: "old_key",
              value: "new old value",
              value_type: "string"
            }
          ])
          expect(success).to eq true
          expect(settings.size).to eq 2
          expect(settings.all? { |setting| setting.errors.empty? }).to eq true
          expect(settings.all?(&:persisted?)).to eq true
          new_key = SuperSettings::Setting.find_by_key("new_key")
          old_key = SuperSettings::Setting.find_by_key("old_key")
          expect(new_key.value).to eq "new value"
          expect(new_key.deleted).to be(false)
          expect(old_key.value).to eq "new old value"
          expect(old_key.deleted).to be(false)
        end

        it "should undelete a setting if it already existed" do
          setting = SuperSettings::Setting.create!(key: "test", value: "oldvalue", deleted: true)
          success, settings = SuperSettings::Setting.bulk_update([
            {
              key: "test",
              value: "foobar",
              value_type: "string"
            }
          ])
          expect(success).to eq true
          new_setting = SuperSettings::Setting.find_by_key("test")
          expect(new_setting.value).to eq "foobar"
          expect(new_setting.deleted).to be(false)
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
  end
end
