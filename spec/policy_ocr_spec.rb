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
      expect { PolicyOcr.checksum('123') }.to raise_error(ArgumentError)
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
      expect(PolicyOcr.valid?('123')).to be false
      expect(PolicyOcr.valid?('abcde1234')).to be false
      expect(PolicyOcr.valid?('34588286?')).to be false
    end
  end

  describe '.write_results' do
    it 'writes one line per entry, with ILL/ERR tags' do
      input = Tempfile.new('ocr_in')
      output = Tempfile.new('ocr_out')
      input.write(fixture('sample'))
      input.rewind
      output.close # we'll overwrite

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

  describe 'ambiguous (AMB) corrections' do
    it 'flags AMB when more than one valid single‑segment fix exists' do
      # make the first digit completely unreadable
      blank = ' ' * 9
      pattern0 = digit_to_pattern['0']
      pattern1 = digit_to_pattern['1']
      pattern7 = digit_to_pattern['7']

      # eight zeros after the blank
      patterns = [blank] + [pattern0] * 8

      # stub neighbors so only the blank slot yields two possible fixes
      allow(PolicyOcr).to receive(:neighbors) do |pat|
        pat == blank ? [pattern1, pattern7] : []
      end

      # force any candidate number to pass checksum
      allow(PolicyOcr).to receive(:valid?).and_return(true)

      _, tag = PolicyOcr.correct_entry(patterns)
      expect(tag).to eq('AMB')
    end
  end

  describe 'bulk‑processing performance' do
    it 'handles 500 entries in under 0.5s' do
      require 'benchmark'
      zero_entry = [
        " _  _  _  _  _  _  _  _  _ ",
        "| || || || || || || || || |",
        "|_||_||_||_||_||_||_||_||_|",
        ""
      ]

      input = Tempfile.new('bulk')
      500.times { zero_entry.each { |line| input.write(line + "\n") } }
      input.rewind

      time = Benchmark.realtime do
        PolicyOcr.write_results_with_guess(input.path, '/dev/null')
      end

      expect(time).to be < 0.5
    ensure
      input.close!
    end
  end

  describe 'mod-13 tiebreaker' do
    it 'picks the single candidate divisible by 13 when there are multiple fixes' do
      # 1) Build a dummy entry with 9 patterns: blank for cell0, anything else for rest
      blank = ' ' * 9
      other = '_' * 9 # dummy pattern for the other 8 cells
      patterns = [blank] + Array.new(8, other)

      # 2) Stub neighbors(blank) => these three fake patterns
      p0, p1, p2 = 'p0pat', 'p1pat', 'p2pat'
      allow(PolicyOcr).to receive(:neighbors) do |pat|
        pat == blank ? [p0, p1, p2] : []
      end

      # 3) Stub parse_entry to map those fake patterns to 9-digit strings
      allow(PolicyOcr).to receive(:parse_entry) do |pats|
        case pats.first
        when p0 then '260000000' # 26 × 10⁷, divisible by 13
        when p1 then '270000000' # 27 × 10⁷, NOT divisible by 13
        when p2 then '280000000' # 28 × 10⁷, NOT divisible by 13
        else '?' * 9 # initial raw parse is all “?” → ILL
        end
      end

      # 4) Stub valid? so all three are “valid” from the checksum perspective
      allow(PolicyOcr).to receive(:valid?).and_return(true)

      # 5) Run the correction
      corrected, tag = PolicyOcr.correct_entry(patterns)

      # We expect the unique mod-13 winner, with no tag
      expect(corrected).to eq('260000000')
      expect(tag).to eq('')
    end
  end
end
