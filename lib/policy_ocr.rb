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
  end