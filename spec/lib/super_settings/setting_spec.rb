# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::Setting do
  after do
    SuperSettings::Setting.cache = nil
  end

  [SuperSettings::Storage::ActiveRecordStorage, SuperSettings::Storage::RedisStorage].each do |storage|
    describe storage.name do
      before do
        SuperSettings::Setting.storage = storage
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
            expect(setting.secret?).to eq false
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
            expect(setting.secret?).to eq false
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
            expect(setting.secret?).to eq false
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
            expect(setting.secret?).to eq false
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
            expect(setting.secret?).to eq false
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
            expect(setting.secret?).to eq false
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

        describe "secret" do
          it "should identify as a secret" do
            setting = SuperSettings::Setting.new(key: "test", value_type: :secret)
            expect(setting.string?).to eq false
            expect(setting.integer?).to eq false
            expect(setting.float?).to eq false
            expect(setting.boolean?).to eq false
            expect(setting.datetime?).to eq false
            expect(setting.array?).to eq false
            expect(setting.secret?).to eq true
          end

          it "should use nil for blank values" do
            setting = SuperSettings::Setting.new(key: "test", value_type: :secret)
            expect(setting.value).to eq nil
            setting.value = ""
            setting.save!
            setting.reload
            expect(setting.value).to eq nil
          end

          it "should store the raw value unencrypted if there is no secret" do
            SuperSettings.secret = nil
            setting = SuperSettings::Setting.create!(key: "test", value: "foo", value_type: :secret)
            expect(setting.value).to eq "foo"
            expect(setting.encrypted?).to eq false
          end

          it "should encrypt and decrypt the value" do
            SuperSettings.secret = "foobar"
            setting = SuperSettings::Setting.create!(key: "test", value: "foo", value_type: :secret)
            expect(setting.value).to eq "foo"
            expect(setting.encrypted?).to eq true
          end

          it "should encrypt and decrypt the value using overloaded secrets" do
            SuperSettings.secret = "foobar"
            setting = SuperSettings::Setting.create!(key: "test", value: "foo", value_type: :secret)
            SuperSettings.secret = ["newsecret", "foobar"]
            expect(setting.value).to eq "foo"
            expect(setting.encrypted?).to eq true
          end

          it "should return nil if the value cannot be decrypted" do
            SuperSettings.secret = "foobar"
            setting = SuperSettings::Setting.create!(key: "test", value: "foo", value_type: :secret)
            SuperSettings.secret = "newsecret"
            expect(setting.value).to eq nil
            expect(setting.encrypted?).to eq true
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

      describe "all_settings" do
        it "should return all settings" do
          setting_1 = SuperSettings::Setting.create!(key: "setting.1", value: "foo")
          setting_2 = SuperSettings::Setting.create!(key: "setting.2", value: "foo", deleted: true)
          setting_3 = SuperSettings::Setting.create!(key: "setting.3", value: "foo")
          expect(SuperSettings::Setting.all_settings.collect(&:key)).to match_array(["setting.1", "setting.2", "setting.3"])
        end
      end

      describe "updated_since" do
        it "should return all settings updated since a specified time" do
          setting_1 = SuperSettings::Setting.create!(key: "setting.1", value: "foo", updated_at: 1.second.ago)
          timestamp = Time.now
          setting_2 = SuperSettings::Setting.create!(key: "setting.2", value: "foo", deleted: true)
          setting_3 = SuperSettings::Setting.create!(key: "setting.3", value: "foo")
          expect(SuperSettings::Setting.updated_since(timestamp).collect(&:key)).to match_array(["setting.2", "setting.3"])
        end
      end

      describe "active_settings" do
        it "should return only the active settings" do
          setting_1 = SuperSettings::Setting.create!(key: "setting.1", value: "foo")
          setting_2 = SuperSettings::Setting.create!(key: "setting.2", value: "foo", deleted: true)
          setting_3 = SuperSettings::Setting.create!(key: "setting.3", value: "foo")
          expect(SuperSettings::Setting.active_settings.collect(&:key)).to match_array(["setting.1", "setting.3"])
        end
      end

      describe "last_updated_at" do
        it "should get the last updated at timestamp for any record" do
          setting_1 = SuperSettings::Setting.create!(key: "test1", value: "foobar", updated_at: 10.seconds.ago)
          expect(SuperSettings::Setting.last_updated_at).to eq setting_1.reload.updated_at
          setting_2 = SuperSettings::Setting.create!(key: "test2", value: "foobar", updated_at: 5.seconds.ago)
          expect(SuperSettings::Setting.last_updated_at).to eq setting_2.reload.updated_at
          setting_1.update!(value: "new value")
          expect(SuperSettings::Setting.last_updated_at).to eq setting_1.reload.updated_at
        end

        it "should cache the last updated timestamp" do
          cache = ActiveSupport::Cache::MemoryStore.new
          SuperSettings::Setting.cache = cache
          setting = SuperSettings::Setting.create!(key: "test", value: "foobar", updated_at: 10.seconds.ago)
          last_updated_at = SuperSettings::Setting.last_updated_at
          expect(SuperSettings::Setting.last_updated_at).to eq last_updated_at
          expect(cache.read(SuperSettings::Setting::LAST_UPDATED_CACHE_KEY)).to eq last_updated_at
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

        it "should not record values on secret settings" do
          setting = SuperSettings::Setting.create!(key: "test", value: "foobar", value_type: :secret)
          setting.update!(value: "bizbaz")
          histories = setting.history(limit: 10)
          expect(histories.collect(&:value)).to eq [nil, nil]
        end

        it "should redact values in the history if the setting is changed to a secret" do
          setting = SuperSettings::Setting.create!(key: "test", value: "foobar", value_type: :string)
          setting.update!(value: "bizbaz", value_type: :secret)
          histories = setting.history(limit: 10)
          expect(histories.collect(&:value)).to eq [nil, nil]
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
              delete: "1"
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
          expect(setting_1.reload.value).to eq "new value"
          expect(setting_2.reload.deleted?).to eq true
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
          expect(setting_1.reload.value).to eq "foobar"
          expect(SuperSettings::Setting.find_by_key("newkey")).to eq nil
        end
      end
    end
  end
end
