# frozen_string_literal: true

require_relative "../../spec_helper"

class TestTransactionStorage
  include SuperSettings::Storage::Transaction

  attr_accessor :updated_at, :created_at

  class << self
    def save_all(changes)
      true
    end
  end
end

describe SuperSettings::Storage::Transaction do
  it "enqueues all changes in a transaction and calls save_all" do
    object_1 = TestTransactionStorage.new
    object_2 = TestTransactionStorage.new
    expect(TestTransactionStorage).to receive(:save_all).with([object_1, object_2]).and_call_original
    TestTransactionStorage.transaction do
      object_1.save!
      object_2.save!
    end
  end

  it "sets the updated and created at timestamps" do
    object = TestTransactionStorage.new
    expect(object.updated_at).to eq nil
    expect(object.created_at).to eq nil
    object.save!
    expect(object.updated_at).to be_a(Time)
    expect(object.created_at).to be_a(Time)
  end

  it "does not set the created at timestamp if it is already set" do
    object = TestTransactionStorage.new
    created_time = Time.now - 100
    object.created_at = created_time
    object.save!
    expect(object.created_at).to eq created_time
  end

  it "sets the persisted flag if save_all succeeds" do
    object1 = TestTransactionStorage.new
    object2 = TestTransactionStorage.new
    expect(object1.persisted?).to eq false
    expect(object2.persisted?).to eq false
    TestTransactionStorage.transaction do
      object1.save!
      object2.save!
    end
    expect(object1.persisted?).to eq true
    expect(object2.persisted?).to eq true
  end

  it "does not set the persisted flag if save_all fails" do
    object1 = TestTransactionStorage.new
    object2 = TestTransactionStorage.new
    expect(object1.persisted?).to eq false
    expect(object2.persisted?).to eq false
    expect(TestTransactionStorage).to receive(:save_all).and_return(false)
    TestTransactionStorage.transaction do
      object1.save!
      object2.save!
    end
    expect(object1.persisted?).to eq false
    expect(object2.persisted?).to eq false
  end
end
