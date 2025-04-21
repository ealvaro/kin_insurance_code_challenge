# frozen_string_literal: true
module PolicyOcr
    # maps the 3×3 “OCR” pattern of each digit (concatenated row‑wise) to its character
  RENDER_PATTERNS = {
    "0" => [
      " _ ",
      "| |",
      "|_|"],
    "1" => [
      "   ",
      "  |",
      "  |"],
    "2" => [
      " _ ",
      " _|",
      "|_ "],
    "3" => [
      " _ ",
      " _|",
      " _|"],
    "4" => [
      "   ",
      "|_|",
      "  |"],
    "5" => [
      " _ ",
      "|_ ",
      " _|"],
    "6" => [
      " _ ",
      "|_ ",
      "|_|"],
    "7" => [
      " _ ",
      "  |",
      "  |"],
    "8" => [
      " _ ",
      "|_|",
      "|_|"],
    "9" => [
      " _ ",
      "|_|",
      " _|"]
    }.freeze
    # maps the 3×3 “OCR” pattern of each digit (concatenated row‑wise) to its character
    DIGIT_PATTERNS = RENDER_PATTERNS.transform_values { |rows| rows.join }.invert.freeze
    ALL_PATTERNS = DIGIT_PATTERNS.keys.freeze

    # @param path [String] path to OCR text file
    # @return [Array<Array<String>>] list of entries; each entry is an Array of 9 raw 3×3 patterns
    def self.load_patterns(path)
      lines = File.readlines(path, chomp: true)
      raise ArgumentError, "File length must be a multiple of 4 lines" unless lines.size % 4 == 0
  
      lines.each_slice(4).map do |top, mid, bot, _blank|
        (0...9).map { |i| top[i*3,3] + mid[i*3,3] + bot[i*3,3] }
      end
    end

    # Parses the entire file at `path` into an Array of 9‑character strings
    # (one entry per 4 lines)
    #
    # @param path[String] path to your OCR text file
    # @return [Array<String>] each element is the 9‑digit (or “?”) string
    def self.parse_file(path)
      load_patterns(path).map { |pats| parse_entry(pats) }
    end
  
    # Parses one 4‑line entry into its 9‑character string
    #
    # @param patterns [Array<String>] array of 9 OCR patterns
    # @return [String] 9-character string, using "?" for unrecognized digits
    def self.parse_entry(patterns)
      patterns.map { |pat| DIGIT_PATTERNS.fetch(pat, "?") }.join
    end

    # Calculate the “mod‑11” checksum for a 9‑digit policy number.
    #
    # @param policy_number [String] exactly 9 characters, each '0'–'9'
    # @return [Integer] the checksum: (d1 + 2*d2 + … + 9*d9) % 11
    # @raise [ArgumentError] if policy_number is not a 9‑digit string
    def self.checksum(policy_number)
      unless policy_number =~ /\A\d{9}\z/
        raise ArgumentError, "policy_number must be a 9‑digit string"
      end

      # reverse so that index 0 (weight 1) is the rightmost digit (d1)
      policy_number
        .chars
        .reverse
        .map.with_index(1) { |char, weight| char.to_i * weight }
        .sum % 11
    end

    # Returns true iff the policy number is numeric, 9 characters,
    # and its checksum is 0.
    #
    # @param policy_number [String]
    # @return [Boolean] true if checksum == 0
    def self.valid?(policy_number)
      checksum(policy_number) == 0
    rescue ArgumentError
      false
    end
    
    # Given a raw 9‑char policy string, return it plus any status tag:
    #  • “ ILL” if it contains “?”
    #  • “ ERR” if it’s all digits but checksum fails
    #  • “” otherwise
    #
    # @param raw [String] 9 chars, digits or “?”
    # @return [String] e.g. "86110??36 ILL"
    def self.format_result(raw)
      if raw.include?('?')
        "#{raw} ILL"
      elsif !valid?(raw)
        "#{raw} ERR"
      else
        raw
      end
    end

    # Process one input file and write an output file, one line per entry.
    #
    # @param input_path[String]  path to the OCR‐style text file
    # @param output_path[String] path to write results to
    # @return [void]
    def self.write_results(input_path, output_path)
      entries = parse_file(input_path)
      lines   = entries.map { |raw| format_result(raw) }
      File.open(output_path, 'w') do |f|
        lines.each { |line| f.puts line }
      end
    end

    # @param pattern [String] a 9‑char OCR pattern
    # @return [Array<String>] all valid patterns at Hamming distance == 1
    def self.neighbors(pattern)
      ALL_PATTERNS.select { |cand|
        pattern.chars.zip(cand.chars).count { |a, b| a != b } == 1
      }
    end

    # Try to correct a single‑segment error in exactly one digit‑box.
    #
    # @param patterns [Array<String>] array of 9 OCR patterns
    # @return [Array(String,String)] [corrected_number, tag] where tag is ""|"ILL"|"ERR"|"AMB"
    def self.correct_entry(patterns)
      raw = parse_entry(patterns)
      original_tag =
        if raw.include?('?') then "ILL"
        elsif !valid?(raw)    then "ERR"
        else                      ""
        end

      return [raw, ""] if original_tag.empty?

      fixes = []
      patterns.each_with_index do |pat, idx|
        neighbors(pat).each do |fixed|
          trial = patterns.dup
          trial[idx] = fixed
          num = parse_entry(trial)
          next if num.include?("?")
          fixes << num if valid?(num)
        end
      end

      uniq = fixes.uniq
      case uniq.size
      when 1 then [uniq.first,     ""           ]
      when 0 then [raw,            original_tag ]
      else       [raw,            "AMB"        ]
      end
    end

    # Swaps in correct_entry when writing results
    # @param input_path [String]
    # @param output_path [String]
    # @return [void]
    def self.write_results_with_guess(input_path, output_path)
      File.open(output_path, 'w') do |out|
        load_patterns(input_path).each do |patterns|
          num, tag = correct_entry(patterns)
          out.puts(tag.empty? ? num : "#{num} #{tag}")
        end
      end
    end
  end
