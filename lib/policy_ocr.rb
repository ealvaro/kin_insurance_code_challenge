# frozen_string_literal: true
module PolicyOcr
    # maps the 3×3 “OCR” pattern of each digit (concatenated row‑wise) to its character
    DIGIT_PATTERNS = {
      " _ | ||_|" => "0",
      "     |  |" => "1",
      " _  _||_ " => "2",
      " _  _| _|" => "3",
      "   |_|  |" => "4",
      " _ |_  _|" => "5",
      " _ |_ |_|" => "6",
      " _   |  |" => "7",
      " _ |_||_|" => "8",
      " _ |_| _|" => "9"
    }.freeze
  
    # Parses the entire file at `path` into an Array of 9‑character strings
    # (one entry per 4 lines)
    #
    # @param path[String] path to your OCR text file
    # @return [Array<String>] each element is the 9‑digit (or “?”) string
    def self.parse_file(path)
      lines = File.readlines(path, chomp: true)
      # Group into 4-line entries (last line is blank)
      entries = lines.each_slice(4).to_a
      entries.map { |entry_lines| parse_entry(entry_lines) }
    end
  
    # Parses one 4‑line entry into its 9‑character string
    #
    # @param lines[Array<String>] exactly 4 elements
    # @return [String] 9‑char result, using "?" for any unrecognized digit
    def self.parse_entry(lines)
      unless lines.size == 4
        raise ArgumentError, "Expected 4 lines per entry, got #{lines.size}"
      end
  
      # take the first 3 rows, chop them into 9 chunks of width 3, then look up each
      (0...9).map do |i|
        pattern = lines[0][i*3,3] + lines[1][i*3,3] + lines[2][i*3,3]
        DIGIT_PATTERNS.fetch(pattern, "?")
      end.join
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
    # @return [Boolean]
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
  end