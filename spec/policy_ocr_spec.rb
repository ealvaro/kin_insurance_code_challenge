require 'tempfile'
require 'byebug'
require_relative '../lib/policy_ocr'

# simple helper so your existing "loads the sample.txt" test passes
def fixture(name)
  File.read(
    File.expand_path("../spec/fixtures/#{name}.txt", __dir__),
    chomp: true
  )
end

RSpec.describe PolicyOcr do
  it "loads" do
    expect(PolicyOcr).to be_a Module
  end

  it 'loads the sample.txt' do
    # your original test: fixture('sample').lines.count => 44
    expect(fixture('sample').lines.count).to eq(44)
  end

  it 'parses each entry into the expected 9‑digit strings' do
    file = Tempfile.new('ocr')
    file.write(fixture('sample'))
    file.rewind
  
    result = PolicyOcr.parse_file(file.path)
  
    expected = [
      '000000000',
      '111111111',
      '222222222',
      '333333333',
      '444444444',
      '555555555',
      '666666666',
      '777777777',
      '888888888',
      '999999999',
      '123456789'
    ]
  
    expect(result).to eq(expected)
  ensure
    file.close!
  end
end