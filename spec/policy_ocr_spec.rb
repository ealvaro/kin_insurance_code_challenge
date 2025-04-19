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

  describe '.checksum' do
    it 'computes the correct mod‑11 checksum' do
      # example from prompt: 3 4 5 8 8 2 8 6 5 => checksum 0
      expect(PolicyOcr.checksum('345882865')).to eq(0)

      # a simple invalid one: all 1s → sum 45 % 11 == 1
      expect(PolicyOcr.checksum('111111111')).to eq(1)
    end

    it 'raises if the input is not exactly 9 digits' do
      expect { PolicyOcr.checksum('123')       }.to raise_error(ArgumentError)
      expect { PolicyOcr.checksum('abcd56789') }.to raise_error(ArgumentError)
    end
  end

  describe '.valid?' do
    it 'returns true for valid policy numbers' do
      expect(PolicyOcr.valid?('345882865')).to be true
      expect(PolicyOcr.valid?('000000000')).to be true
    end

    it 'returns false for invalid or malformed inputs' do
      expect(PolicyOcr.valid?('111111111')).to be false
      expect(PolicyOcr.valid?('123')).to       be false
      expect(PolicyOcr.valid?('abcde1234')).to be false
      expect(PolicyOcr.valid?('34588286?')).to be false
    end
  end

  describe '.write_results' do
    it 'writes one line per entry, with ILL/ERR tags' do
      input  = Tempfile.new('ocr_in')
      output = Tempfile.new('ocr_out')
      input.write(fixture('sample'))
      input.rewind
      output.close  # we'll overwrite
  
      PolicyOcr.write_results(input.path, output.path)
  
      actual = File.readlines(output.path, chomp: true)
      expected = PolicyOcr.parse_file(input.path).map do |raw|
        PolicyOcr.format_result(raw)
      end
  
      expect(actual).to eq(expected)
    ensure
      input.close!
      output.close!
    end
  end

  let(:digit_to_pattern) { PolicyOcr::DIGIT_PATTERNS.invert }

  describe '.correct_entry' do
    it 'fixes a single‐segment error and returns no tag' do
      original = '345882865'
      # break that into its 9 patterns
      patterns = original.chars.map { |d| digit_to_pattern[d] }

      # simulate missing one "|" in the first digit's 3×3
      bad0 = patterns.first.dup
      bad0[bad0.index('|')] = ' '
      patterns_error = [bad0] + patterns[1..-1]

      corrected, status = PolicyOcr.correct_entry(patterns_error)
      expect(corrected).to eq(original)
      expect(status).to eq('')
    end

    it 'leaves it ILL when no single‐segment fix yields a valid checksum' do
      original = '345882865'
      patterns = original.chars.map { |d| digit_to_pattern[d] }

      # completely blank out the first digit
      blank = ' ' * 9
      patterns_error = [blank] + patterns[1..-1]

      corrected, status = PolicyOcr.correct_entry(patterns_error)
      expect(corrected).to eq('?45882865')
      expect(status).to eq('ILL')
    end
  end
end