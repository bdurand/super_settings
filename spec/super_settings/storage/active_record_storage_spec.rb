# frozen_string_literal: true

require_relative "../../spec_helper"

if EXTENSIONS[:active_record]
  describe SuperSettings::Storage::ActiveRecordStorage do
    before do
      SuperSettings::Storage::ActiveRecordStorage.destroy_all
    end

    describe "all" do
      it "should return all settings" do
        setting_1 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_1", raw_value: "1")
        setting_1.save!
        setting_2 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_2", deleted: true)
        setting_2.save!
        setting_3 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_3", raw_value: "3")
        setting_3.save!
        settings = SuperSettings::Storage::ActiveRecordStorage.all
        expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::ActiveRecordStorage]
        expect(settings.collect(&:key)).to match_array(["setting_1", "setting_2", "setting_3"])
      end
    end

    describe "active" do
      it "should return only non-deleted settings" do
        setting_1 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_1", raw_value: "1")
        setting_1.save!
        setting_2 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_2", deleted: true)
        setting_2.save!
        setting_3 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_3", raw_value: "3")
        setting_3.save!
        settings = SuperSettings::Storage::ActiveRecordStorage.active
        expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::ActiveRecordStorage]
        expect(settings.collect(&:key)).to match_array(["setting_1", "setting_3"])
      end
    end

    describe "updated_since" do
      it "should return settings updated since a timestamp" do
        setting_1 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_1", raw_value: "1", updated_at: Time.now - 100)
        setting_1.save!
        setting_2 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_2", raw_value: "2", updated_at: Time.now - 50)
        setting_2.save!
        setting_3 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_3", raw_value: "3")
        setting_3.save!
        settings = SuperSettings::Storage::ActiveRecordStorage.updated_since(Time.now - 60)
        expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::ActiveRecordStorage]
        expect(settings.collect(&:key)).to match_array(["setting_2", "setting_3"])
      end
    end

    describe "find_by_key" do
      it "should return settings updated since a timestamp" do
        setting_1 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_1", raw_value: "1", updated_at: Time.now - 100)
        setting_1.save!
        setting_2 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_2", raw_value: "2", updated_at: Time.now - 50)
        setting_2.save!
        expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting_1")).to eq setting_1
        expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting_2")).to eq setting_2
        expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("not_exist")).to eq nil
        expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting_1").persisted?).to eq true
      end
    end

    describe "persistence" do
      it "inserts, updates, and deletes records" do
        setting = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting", raw_value: "1", updated_at: Time.now - 100)
        setting.save!
        expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting").raw_value).to eq "1"
        setting.raw_value = "2"
        setting.save!
        expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting").raw_value).to eq "2"
        setting.deleted = true
        setting.save!
        expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting")).to eq nil
        new_setting = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting", raw_value: "3", updated_at: Time.now - 100)
        new_setting.save!
        expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting").raw_value).to eq "3"
        expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting").deleted?).to eq false
      end
    end

    describe "last_updated_at" do
      it "should return the last time a setting was updated" do
        setting_1 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_1", raw_value: "1", updated_at: Time.now - 100)
        setting_1.save!
        setting_2 = SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_2", raw_value: "2", updated_at: Time.at(Time.now - 50))
        setting_2.save!
        setting_2 = SuperSettings::Storage::ActiveRecordStorage.find_by_key(setting_2.key)
        expect(SuperSettings::Storage::ActiveRecordStorage.last_updated_at).to eq setting_2.updated_at
      end
    end

    describe "attributes" do
      it "should cast all the attributes" do
        setting = SuperSettings::Storage::ActiveRecordStorage.new(key: "key", raw_value: "1", value_type: "integer", description: "text", updated_at: Time.now, created_at: Time.now - 10)
        expect(setting.persisted?).to eq false
        setting.save!

        expect(setting.persisted?).to eq true
        expect(setting.key).to eq "key"
        expect(setting.raw_value).to eq "1"
        expect(setting.value_type).to eq "integer"
        expect(setting.description).to eq "text"
        expect(setting.deleted?).to eq false
        expect(setting.updated_at).to be_a(Time)
        expect(setting.created_at).to be_a(Time)
      end
    end

    describe "history" do
      it "should fetch the setting history" do
        setting = SuperSettings::Storage::ActiveRecordStorage.new(key: "key", raw_value: "1")
        setting.save!
        SuperSettings::Storage::ActiveRecordStorage.create_history(key: "key", value: "1", changed_by: "me", created_at: Time.now - 30)
        SuperSettings::Storage::ActiveRecordStorage.create_history(key: "key", value: "2", changed_by: "you", created_at: Time.now - 20)
        SuperSettings::Storage::ActiveRecordStorage.create_history(key: "key", deleted: true, changed_by: "Bob", created_at: Time.now - 10)
        histories = setting.history
        expect(histories.collect(&:value)).to eq [nil, "2", "1"]
        expect(histories.collect(&:deleted?)).to eq [true, false, false]
        expect(histories.collect(&:changed_by)).to eq ["Bob", "you", "me"]
        expect(setting.history(limit: 1, offset: 1).collect(&:value)).to eq ["2"]
        expect(setting.history(limit: 1, offset: 2).collect(&:value)).to eq ["1"]
      end
    end

    context "when there is no database connection" do
      before do
        SuperSettings::Storage::ActiveRecordStorage.new(key: "setting_1", raw_value: "1").save!
        allow(SuperSettings::Storage::ActiveRecordStorage::Model).to receive(:available?).and_return(false)
      end

      it "should not fetch a connection" do
        value = nil
        expect(SuperSettings::Storage::ActiveRecordStorage::Model.connection_pool).to_not receive(:with_connection)
        SuperSettings::Storage::ActiveRecordStorage.with_connection { value = true }
        expect(value).to be true
      end

      it "should not open a transaction" do
        value = nil
        expect(SuperSettings::Storage::ActiveRecordStorage::Model).to_not receive(:transaction)
        SuperSettings::Storage::ActiveRecordStorage.transaction { value = true }
        expect(value).to be true
      end

      it "should return an empty array for all" do
        expect(SuperSettings::Storage::ActiveRecordStorage.all).to eq []
      end

      it "should return an empty array for active" do
        expect(SuperSettings::Storage::ActiveRecordStorage.active).to eq []
      end

      it "should return an empty array for updated_since" do
        expect(SuperSettings::Storage::ActiveRecordStorage.updated_since(Time.now)).to eq []
      end

      it "should return nil for find_by_key" do
        expect(SuperSettings::Storage::ActiveRecordStorage.find_by_key("setting_1")).to eq nil
      end

      it "should return nil for last_updated_at" do
        expect(SuperSettings::Storage::ActiveRecordStorage.last_updated_at).to eq nil
      end
    end
  end
end
