# frozen_string_literal: true

describe "web UI", type: :feature, js: true do
  let!(:string_setting) { SuperSettings::Setting.create!(key: "key.string", value: "foo", value_type: "string", description: "string description") }
  let!(:integer_setting) { SuperSettings::Setting.create!(key: "key.integer", value: 55, value_type: "integer") }
  let!(:float_setting) { SuperSettings::Setting.create!(key: "key.float", value: 4.5, value_type: "float") }
  let!(:boolean_setting) { SuperSettings::Setting.create!(key: "key.boolean", value: true, value_type: "boolean") }
  let!(:datetime_setting) { SuperSettings::Setting.create!(key: "key.datetime", value: Time.new(2021, 9, 11, 12, 47), value_type: "datetime") }
  let!(:array_setting) { SuperSettings::Setting.create!(key: "key.array", value: ["one", "two", "three"], value_type: "array") }
  let!(:secret_setting) { SuperSettings::Setting.create!(key: "key.secret", value: "secretvalue", value_type: "secret") }

  def find_setting_id(key)
    find("tr[data-key=\"#{key}\"]")["data-id"]
  end

  def find_setting_field(id, name, visible: nil)
    find("[name=\"settings[#{id}][#{name}]\"]", visible: visible)
  end

  def within_setting_row(id, &block)
    within("tr[data-id=#{id}]", &block)
  end

  describe "showing settings" do
    it "should load all settings" do
      visit "/"
      expect(page).to have_content("key.string")
      expect(page).to have_content("foo")
      expect(page).to have_content("string description")
      expect(page).to have_content("key.integer")
      expect(page).to have_content("55")
      expect(page).to have_content("key.float")
      expect(page).to have_content("4.5")
      expect(page).to have_content("key.boolean")
      expect(page).to have_content("true")
      expect(page).to have_content("key.datetime")
      expect(page).to have_content(datetime_setting.value.httpdate.sub("GMT", "UTC"))
      expect(page).to have_content("key.array")
      expect(page).to have_content("one\ntwo\nthree")
      expect(page).to have_content("key.secret")
      expect(page).to have_content("•••")
      expect(page).to_not have_content("secretvalue")
    end

    it "should filter settings" do
      visit "/?filter=str"
      expect(page).to have_content("key.string")
      expect(page).to_not have_content("key.integer")
      expect(page).to_not have_content("key.float")
      expect(page).to_not have_content("key.boolean")
      expect(page).to_not have_content("key.datetime")
      expect(page).to_not have_content("key.array")
      expect(page).to_not have_content("key.secret")

      fill_in("filter", with: "G")
      expect(page).to have_content("key.string")
      expect(page).to have_content("key.integer")
      expect(page).to_not have_content("key.float")
      expect(page).to_not have_content("key.boolean")
      expect(page).to_not have_content("key.datetime")
      expect(page).to_not have_content("key.array")
      expect(page).to_not have_content("key.secret")

      fill_in("filter", with: " ")
      expect(page).to have_content("key.string")
      expect(page).to have_content("key.integer")
      expect(page).to have_content("key.float")
      expect(page).to have_content("key.boolean")
      expect(page).to have_content("key.datetime")
      expect(page).to have_content("key.array")
      expect(page).to have_content("key.secret")
    end
  end

  describe "edit settings" do
    def test_edit_setting(setting, &block)
      visit "/"
      id = find_setting_id(setting.key)
      within_setting_row(id) do
        find("a.js-edit-setting").click
        key_field = find("input[name=\"settings[#{id}][key]\"]")
        expect(key_field[:type]).to eq "text"
        expect(key_field.value).to eq setting.key

        value_type_field = find("select[name=\"settings[#{id}][value_type]\"]")
        expect(value_type_field.value).to eq setting.value_type

        description_field = find("textarea[name=\"settings[#{id}][description]\"]")
        expect(description_field.value).to eq setting.description.to_s

        value_field = find("[name=\"settings[#{id}][value]\"]", visible: :all)
        yield value_field
      end
    end

    it "should edit strings" do
      test_edit_setting(string_setting) do |value_field|
        expect(value_field.tag_name).to eq "textarea"
        expect(value_field.value).to eq string_setting.value.to_s
      end
    end

    it "should edit integers" do
      test_edit_setting(integer_setting) do |value_field|
        expect(value_field.tag_name).to eq "input"
        expect(value_field[:type]).to eq "number"
        expect(value_field[:step]).to eq "1"
        expect(value_field.value).to eq integer_setting.value.to_s
      end
    end

    it "should edit floats" do
      test_edit_setting(float_setting) do |value_field|
        expect(value_field.tag_name).to eq "input"
        expect(value_field[:type]).to eq "number"
        expect(value_field[:step]).to eq "any"
        expect(value_field.value).to eq float_setting.value.to_s
      end
    end

    it "should edit booleans" do
      test_edit_setting(boolean_setting) do |value_field|
        expect(value_field.tag_name).to eq "input"
        expect(value_field[:type]).to eq "checkbox"
        expect(value_field.value).to eq "true"
        expect(value_field[:checked]).to eq true
      end
    end

    it "should edit datetimes" do
      test_edit_setting(datetime_setting) do |value_field|
        expect(value_field.tag_name).to eq "input"
        expect(value_field[:type]).to eq "hidden"
        expect(Time.parse(value_field.value)).to eq datetime_setting.value
      end
    end

    it "should edit arrays" do
      test_edit_setting(array_setting) do |value_field|
        expect(value_field.tag_name).to eq "textarea"
        expect(value_field.value).to eq array_setting.value.join("\n")
      end
    end

    it "should edit secrets" do
      test_edit_setting(secret_setting) do |value_field|
        expect(value_field.tag_name).to eq "textarea"
        expect(value_field.value).to eq secret_setting.value.to_s
      end
    end

    it "should be able to change the value type" do
      visit "/"
      id = find_setting_id("key.float")
      value_type_descriptor = "select[name=\"settings[#{id}][value_type]\"]"
      within_setting_row(id) do
        find("a.js-edit-setting").click

        find(value_type_descriptor).select("integer")
        value_field = find_setting_field(id, :value)
        expect(value_field.tag_name).to eq "input"
        expect(value_field[:type]).to eq "number"
        expect(value_field[:step]).to eq "1"
        expect(value_field.value).to eq "4"

        find(value_type_descriptor).select("string")
        value_field = find("[name=\"settings[#{id}][value]\"]")
        expect(value_field[:type]).to eq "textarea"
        expect(value_field.value).to eq "4"

        find(value_type_descriptor).select("datetime")
        value_field = find("[name=\"settings[#{id}][value]\"]", visible: :all)
        expect(value_field.tag_name).to eq "input"
        expect(value_field[:type]).to eq "hidden"

        find(value_type_descriptor).select("array")
        value_field = find("[name=\"settings[#{id}][value]\"]")
        expect(value_field[:type]).to eq "textarea"

        find(value_type_descriptor).select("boolean")
        value_field = find("[name=\"settings[#{id}][value]\"]")
        expect(value_field.tag_name).to eq "input"
        expect(value_field[:type]).to eq "checkbox"

        find(value_type_descriptor).select("secret")
        value_field = find("[name=\"settings[#{id}][value]\"]")
        expect(value_field[:type]).to eq "textarea"
      end
    end

    it "should cancel changes" do
      visit "/"
      id = find_setting_id("key.string")
      value_type_descriptor = "select[name=\"settings[#{id}][value_type]\"]"
      within_setting_row(id) do
        find("a.js-edit-setting").click
        find_setting_field(id, :key).fill_in(with: "newkey")
        find_setting_field(id, :value).fill_in(with: "newvalue")
        expect(page).to_not have_content("key.string")
        expect(page).to_not have_content("foo")
        find("a.js-restore-setting").click
        expect(page).to have_content("key.string")
        expect(page).to have_content("foo")
      end
    end
  end

  describe "add settings" do
    it "should add a form field" do
      visit "/"
      click_on("Add Setting")
      id = all("tr[data-id]").first["data-id"]
      within_setting_row(id) do
        key_field = find_setting_field(id, :key)
        expect(key_field[:type]).to eq "text"
        expect(key_field.value).to eq ""

        value_field = find_setting_field(id, :value)
        expect(value_field.value).to eq ""

        value_type_field = find("select[name=\"settings[#{id}][value_type]\"]")
        expect(value_type_field.value).to eq "string"

        description_field = find("textarea[name=\"settings[#{id}][description]\"]")
        expect(description_field.value).to eq ""
      end
    end

    it "should cancel changes" do
      visit "/"
      click_on("Add Setting")
      id = all("tr[data-id]").first["data-id"]
      within_setting_row(id) do
        find("a.js-restore-setting").click
      end
      expect(all("tr[data-id=#{id}]").size).to eq 0
    end
  end

  describe "remove settings" do
    it "should mark the setting to be removed" do
      visit "/"
      id = find_setting_id("key.string")
      table_row = find("tr[data-id=#{id}]")
      expect(table_row["data-deleted"]).to eq nil
      table_row.find("a.js-remove-setting").click
      expect(table_row["data-deleted"]).to eq "true"
    end

    it "should cancel changes" do
      visit "/"
      id = find_setting_id("key.string")
      table_row = find("tr[data-id=#{id}]")
      table_row.find("a.js-remove-setting").click
      expect(table_row["data-deleted"]).to eq "true"
      table_row.find("a.js-restore-setting").click
      expect(table_row["data-deleted"]).to eq nil
    end
  end

  describe "discard changes" do
    it "should link to the current page" do
      visit "/"
      discard_changes_button = find("#discard-changes")
      expect(discard_changes_button[:disabled]).to eq true
      click_on("Add Setting")
      expect(discard_changes_button[:disabled]).to eq false
    end
  end

  describe "save changes" do
    it "should save all changes at once" do
      visit "/"
      click_on("Add Setting")
      new_id = all("tr[data-id]").first["data-id"]
      find_setting_field(new_id, :key).fill_in(with: "newkey")
      find_setting_field(new_id, :value).fill_in(with: "newvalue")
      find_setting_field(new_id, :description).fill_in(with: "new description")

      string_id = find_setting_id("key.string")
      within_setting_row(string_id) do
        find("a.js-remove-setting").click
      end

      integer_id = find_setting_id("key.integer")
      within_setting_row(integer_id) do
        find("a.js-edit-setting").click
        find_setting_field(integer_id, :value).fill_in(with: "6688")
      end

      float_id = find_setting_id("key.float")
      within_setting_row(float_id) do
        find("a.js-edit-setting").click
        find_setting_field(float_id, :value).fill_in(with: "77.5")
      end

      boolean_id = find_setting_id("key.boolean")
      within_setting_row(boolean_id) do
        find("a.js-edit-setting").click
        find("input[type=checkbox]").click
      end

      datetime_id = find_setting_id("key.datetime")
      within_setting_row(datetime_id) do
        find("a.js-edit-setting").click
        find("input.js-date-input").fill_in(with: "2020-09-12")
        find("input.js-time-input").fill_in(with: Time.parse("1970-01-01T15:33"))
      end

      array_id = find_setting_id("key.array")
      within_setting_row(array_id) do
        find("a.js-edit-setting").click
        find_setting_field(array_id, :value).fill_in(with: "car\nboat\nplane")
      end

      secret_id = find_setting_id("key.secret")
      within_setting_row(secret_id) do
        find("a.js-edit-setting").click
        find_setting_field(secret_id, :value).fill_in(with: "newsecret")
      end

      find("#save-settings").click

      expect(page).to_not have_content("key.string")
      expect(page).to_not have_content("foo")
      expect(page).to have_content("newkey")
      expect(page).to have_content("newvalue")
      expect(page).to have_content("new description")
      expect(page).to have_content("6688")
      expect(page).to have_content("77.5")
      expect(page).to_not have_content("newsecret")

      expect(SuperSettings::Setting.all.detect { |setting| setting.key == "key.string" }.deleted?).to eq true
      expect(SuperSettings::Setting.find_by_key("key.integer").value).to eq 6688
      expect(SuperSettings::Setting.find_by_key("key.float").value).to eq 77.5
      expect(SuperSettings::Setting.find_by_key("key.boolean").value).to eq false
      expect(SuperSettings::Setting.find_by_key("key.array").value).to eq ["car", "boat", "plane"]
      expect(SuperSettings::Setting.find_by_key("key.datetime").value).to eq Time.utc(2020, 9, 12, 15, 33)
      expect(SuperSettings::Setting.find_by_key("key.secret").value).to eq "newsecret"
    end
  end

  describe "show history" do
    it "should show a paginated list of changes" do
      visit "/"
      25.times do |i|
        integer_setting.update!(value: i)
      end
      integer_id = find_setting_id("key.integer")
      within_setting_row(integer_id) do
        find("a.js-show-history").click
      end
      within("#modal") do
        expect(all("#super-settings-history tbody tr").size).to eq 25
        click_on("Older")
        expect(all("#super-settings-history tbody tr").size).to eq 1
        click_on("Newer")
        expect(all("#super-settings-history tbody tr").size).to eq 25
      end
    end
  end
end
