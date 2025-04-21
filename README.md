# PolicyOcr CLI

**A simple Ruby-based OCR parser and validator for insurance policy numbers.**

---

## Overview

This project provides a command-line interface (CLI) to:

1. **Parse** ASCII-art policy numbers (9 digits, each represented in a 3×3 grid of pipes/underscores)
2. **Validate** their checksums (mod‑11)
3. **Flag** illegible (`ILL`) or erroneous (`ERR`) entries
4. **Guess** single-segment OCR mistakes and correct them when unambiguous, or mark them ambiguous (`AMB`)

It’s implemented in plain Ruby (no Rails dependencies) and tested with RSpec.

---

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/policy_ocr.git
   cd policy_ocr
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Make the CLI executable**
   ```bash
   chmod +x bin/policy_ocr
   ```

4. Ensure Ruby **>= 2.4** is on your PATH.

---

## Usage

Place your input file (ASCII‑OCR text) in the project root as `ocr_in`, or provide your own names.

```bash
# default filenames: ocr_in, ocr_out, ocr_fixed
bin/policy_ocr

# or specify: input output fixed
bin/policy_ocr my_input.txt results.txt corrected.txt
```

After running, you’ll see:

```
✅  Wrote OCR results to /full/path/to/ocr_out
✅  Wrote guessed results to /full/path/to/ocr_fixed
```

- **`ocr_out`**: raw parse + `ILL`/`ERR` tags
- **`ocr_fixed`**: attempted single‑segment fixes + `AMB` tag for ambiguous

---

## Error Handling

The CLI and library provide meaningful messages on failure:

- **File not found**:
  ```
  ERROR: input file not found: /path/to/ocr_in
  ```
- **Invalid format** (lines not in multiples of 4 × 27 chars):
  ```
  ERROR: File length must be a multiple of 4 lines
  ```
- **Checksum failures** are flagged per-entry; they don’t abort the run.

All unexpected exceptions are caught at the CLI level and reported:

```ruby
begin
  PolicyOcr.write_results(input, output)
rescue ArgumentError => e
  abort "ERROR: #{e.message}"  # then exit 1
end
```  

---

## Testing

Run the full suite with RSpec:

```bash
bundle exec rspec
```

Tests cover:
- Parsing (`parse_file`)
- Checksum/validation (`checksum`, `valid?`)
- Formatting (`format_result`, `write_results`)
- Guessing logic (`correct_entry`, `write_results_with_guess`)
- Edge cases: `ILL`, `ERR`, `AMB`
- Performance smoke test (500 entries)

---

## Assumptions & Comments

- Input lines are exactly **27 characters** plus newline.
- Entries are **4 lines** (3 pattern + 1 blank).
- Policy numbers are **9 digits**; unknown segments become `?`.
- Checksum formula: `(1*d₁ + 2*d₂ + … + 9*d₉) mod 11 == 0`.
- Single-segment error correction only flips one pipe/_ in exactly one digit-box.

---

## Code Structure & Conventions

- **`lib/policy_ocr.rb`**: contains `PolicyOcr` module with methods for each user story.
- **`bin/policy_ocr`**: CLI wrapper handling arguments, file existence, and output.
- **`spec/`**: RSpec tests with fixtures in `spec/fixtures/sample.txt`.

All methods include YARD-style `@param`/`@return` comments for clarity.

---

## Contributing

1. Fork the repo
2. Create a feature branch
3. Write your code + tests
4. Submit a pull request

---

## License

MIT © Alvaro Escobar

