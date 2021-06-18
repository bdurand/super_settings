# frozen_string_literal: true

require_relative "../../spec_helper"

describe SuperSettings::Encryption do
  it "should encrypt and decrypt a value" do
    SuperSettings::Encryption.secret = "secret"
    encrypted = SuperSettings::Encryption.encrypt("foo")
    expect(encrypted).to_not eq "foo"
    expect(SuperSettings::Encryption.encrypted?(encrypted)).to eq true
    expect(SuperSettings::Encryption.encrypted?("foo")).to eq false
    expect(SuperSettings::Encryption.decrypt(encrypted)).to eq "foo"
  end

  it "should return the value if it is not encrypted" do
    expect(SuperSettings::Encryption.decrypt("foobar")).to eq "foobar"
  end

  it "should decrypt a value using overloaded secrets" do
    SuperSettings::Encryption.secret = "old"
    encrypted = SuperSettings::Encryption.encrypt("foo")
    SuperSettings::Encryption.secret = ["new", "old"]
    expect(SuperSettings::Encryption.decrypt(encrypted)).to eq "foo"
    SuperSettings::Encryption.secret = ["new"]
    expect { SuperSettings::Encryption.decrypt(encrypted) }.to raise_error(SuperSettings::Encryption::InvalidSecretError)
  end
end
