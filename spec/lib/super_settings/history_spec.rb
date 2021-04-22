# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::History do

  describe "as_json" do
    it "should serialize the record" do
      history = SuperSettings::History.new(key: "test", value: "foobar", changed_by: "Mary", created_at: Time.now)
      expect(history.as_json).to eq({
        key: history.key,
        value: history.value,
        changed_by: history.changed_by,
        created_at: history.created_at
      })
    end
  end

end
