# frozen_string_literal: true

require_relative "../../spec_helper"

if ENV["TEST_S3_URL"]
  describe SuperSettings::Storage::S3Storage do
    before do
      SuperSettings::Storage::S3Storage.destroy_all
    end

    describe ".all" do
      it "should return all settings" do
        setting_1 = SuperSettings::Storage::S3Storage.new(key: "setting_1", raw_value: "1")
        setting_1.save!
        setting_2 = SuperSettings::Storage::S3Storage.new(key: "setting_2", deleted: true)
        setting_2.save!
        setting_3 = SuperSettings::Storage::S3Storage.new(key: "setting_3", raw_value: "3")
        setting_3.save!
        settings = SuperSettings::Storage::S3Storage.all
        expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::S3Storage]
        expect(settings.collect(&:key)).to match_array(["setting_1", "setting_2", "setting_3"])
      end
    end

    describe ".active" do
      it "should return only non-deleted settings" do
        setting_1 = SuperSettings::Storage::S3Storage.new(key: "setting_1", raw_value: "1")
        setting_1.save!
        setting_2 = SuperSettings::Storage::S3Storage.new(key: "setting_2", deleted: true)
        setting_2.save!
        setting_3 = SuperSettings::Storage::S3Storage.new(key: "setting_3", raw_value: "3")
        setting_3.save!
        settings = SuperSettings::Storage::S3Storage.active
        expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::S3Storage]
        expect(settings.collect(&:key)).to match_array(["setting_1", "setting_3"])
      end
    end

    describe ".updated_since" do
      it "should return settings updated since a timestamp" do
        setting_1 = SuperSettings::Storage::S3Storage.new(key: "setting_1", raw_value: "1", updated_at: Time.now - 100)
        setting_1.save!
        setting_2 = SuperSettings::Storage::S3Storage.new(key: "setting_2", raw_value: "2", updated_at: Time.now - 50)
        setting_2.save!
        setting_3 = SuperSettings::Storage::S3Storage.new(key: "setting_3", raw_value: "3", updated_at: Time.now)
        setting_3.save!
        settings = SuperSettings::Storage::S3Storage.updated_since(Time.now - 60)
        expect(settings.collect(&:class).uniq).to eq [SuperSettings::Storage::S3Storage]
        expect(settings.collect(&:key)).to match_array(["setting_2", "setting_3"])
      end
    end

    describe ".find_by_key" do
      it "should find a non-deleted setting by key" do
        setting_1 = SuperSettings::Storage::S3Storage.new(key: "setting_1", raw_value: "1")
        setting_1.save!
        setting_2 = SuperSettings::Storage::S3Storage.new(key: "setting_2", deleted: true)
        setting_2.save!
        expect(SuperSettings::Storage::S3Storage.find_by_key("setting_1")).to eq setting_1
        expect(SuperSettings::Storage::S3Storage.find_by_key("setting_2")).to eq nil
        expect(SuperSettings::Storage::S3Storage.find_by_key("not_exist")).to eq nil
      end
    end

    describe ".last_updated_at" do
      it "should be the last modified time of the object" do
        setting = SuperSettings::Storage::S3Storage.new(
          key: "setting_1",
          raw_value: "1",
          description: "Setting 1",
          value_type: "integer",
          updated_at: Time.now - 100,
          created_at: Time.now - 100
        )
        setting.save!
        settings_object = SuperSettings::Storage::S3Storage.send(:settings_object)
        expect(SuperSettings::Storage::S3Storage.last_updated_at).to eq settings_object.last_modified
      end
    end

    describe "history" do
      it "should save and load settings and history" do
        setting = SuperSettings::Storage::S3Storage.new(
          key: "setting_1",
          raw_value: "1",
          description: "Setting 1",
          value_type: "integer"
        )
        setting.create_history(changed_by: "test", created_at: Time.now - 2)
        setting.save!

        setting = SuperSettings::Storage::S3Storage.find_by_key("setting_1")
        expect(setting.history.length).to eq 1
        expect(setting.history.first.changed_by).to eq "test"

        setting.create_history(changed_by: "test2", created_at: Time.now - 1)
        setting.save!

        setting = SuperSettings::Storage::S3Storage.find_by_key("setting_1")
        expect(setting.history.length).to eq 2
        expect(setting.history.collect(&:changed_by)).to eq ["test2", "test"]
      end
    end
  end
end
