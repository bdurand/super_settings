# frozen_string_literal: true

require_relative "../../spec_helper"

if EXTENSIONS[:mongodb]
  describe SuperSettings::Storage::MongoDBStorage do
    before do
      SuperSettings::Storage::MongoDBStorage.destroy_all
    end

    describe ".all" do
      it "should return all settings" do
        setting_1 = SuperSettings::Storage::MongoDBStorage.new(key: "setting_1", raw_value: "1")
        setting_1.save!
        setting_2 = SuperSettings::Storage::MongoDBStorage.new(key: "setting_2", deleted: true)
        setting_2.save!
        setting_3 = SuperSettings::Storage::MongoDBStorage.new(key: "setting_3", raw_value: "3")
        setting_3.save!
        settings = SuperSettings::Storage::MongoDBStorage.all
        expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::MongoDBStorage]
        expect(settings.collect(&:key)).to match_array(["setting_1", "setting_2", "setting_3"])
      end
    end

    describe ".active" do
      it "should return only non-deleted settings" do
        setting_1 = SuperSettings::Storage::MongoDBStorage.new(key: "setting_1", raw_value: "1")
        setting_1.save!
        setting_2 = SuperSettings::Storage::MongoDBStorage.new(key: "setting_2", deleted: true)
        setting_2.save!
        setting_3 = SuperSettings::Storage::MongoDBStorage.new(key: "setting_3", raw_value: "3")
        setting_3.save!
        settings = SuperSettings::Storage::MongoDBStorage.active
        expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::MongoDBStorage]
        expect(settings.collect(&:key)).to match_array(["setting_1", "setting_3"])
      end
    end

    describe ".updated_since" do
      it "should return settings updated since a timestamp" do
        setting_1 = SuperSettings::Storage::MongoDBStorage.new(key: "setting_1", raw_value: "1", updated_at: Time.now - 100)
        setting_1.save!
        setting_2 = SuperSettings::Storage::MongoDBStorage.new(key: "setting_2", raw_value: "2", updated_at: Time.now - 50)
        setting_2.save!
        setting_3 = SuperSettings::Storage::MongoDBStorage.new(key: "setting_3", raw_value: "3", updated_at: Time.now)
        setting_3.save!
        settings = SuperSettings::Storage::MongoDBStorage.updated_since(Time.now - 60)
        expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::MongoDBStorage]
        expect(settings.collect(&:key)).to match_array(["setting_2", "setting_3"])
      end
    end

    describe ".find_by_key" do
      it "should find a non-deleted setting by key" do
        setting_1 = SuperSettings::Storage::MongoDBStorage.new(key: "setting_1", raw_value: "1")
        setting_1.save!
        setting_2 = SuperSettings::Storage::MongoDBStorage.new(key: "setting_2", deleted: true)
        setting_2.save!
        expect(SuperSettings::Storage::MongoDBStorage.find_by_key("setting_1")).to eq setting_1
        expect(SuperSettings::Storage::MongoDBStorage.find_by_key("setting_2")).to eq nil
        expect(SuperSettings::Storage::MongoDBStorage.find_by_key("not_exist")).to eq nil
      end
    end

    describe ".last_updated_at" do
      it "should be the last modified time of the object" do
        t = Time.at(Time.now.to_i)
        SuperSettings::Storage::MongoDBStorage.new(
          key: "setting_1",
          raw_value: "1",
          description: "Setting 1",
          value_type: "integer",
          updated_at: t - 100,
          created_at: t - 100
        ).save!
        SuperSettings::Storage::MongoDBStorage.new(
          key: "setting_2",
          raw_value: "2",
          description: "Setting 2",
          value_type: "integer",
          updated_at: t - 50,
          created_at: t - 50
        ).save!
        expect(SuperSettings::Storage::MongoDBStorage.last_updated_at).to eq t - 50
      end
    end

    describe "history" do
      it "should save and load settings and history" do
        setting = SuperSettings::Storage::MongoDBStorage.new(
          key: "setting_1",
          raw_value: "1",
          description: "Setting 1",
          value_type: "integer"
        )
        setting.create_history(value: "1", changed_by: "test", created_at: Time.now - 3)
        setting.save!

        setting = SuperSettings::Storage::MongoDBStorage.find_by_key("setting_1")
        expect(setting.history.length).to eq 1
        expect(setting.history.first.changed_by).to eq "test"

        setting.create_history(value: "2", changed_by: "test2", created_at: Time.now - 2, deleted: true)
        setting.create_history(value: "3", changed_by: "test3", created_at: Time.now - 1)
        setting.save!

        setting = SuperSettings::Storage::MongoDBStorage.find_by_key("setting_1")
        expect(setting.history.length).to eq 3
        expect(setting.history.collect(&:changed_by)).to eq ["test3", "test2", "test"]
        expect(setting.history.collect(&:value)).to eq ["3", "2", "1"]
        expect(setting.history.collect(&:deleted?)).to eq [false, true, false]
      end
    end
  end
end
