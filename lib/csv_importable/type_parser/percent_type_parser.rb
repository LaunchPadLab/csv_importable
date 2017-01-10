module CSVImportable
  class TypeParser::PercentTypeParser < TypeParser
    def parse_val
      val = parse_percentage_sign if value.to_s.include?("%")
      val = val.present? ? val : Float(value)
      outside_range if val < 0 || val > 1
      val
    end

    def error_message
      "Invalid percent for column: #{key}. It should be a decimal between 0 and 1."
    end

    def outside_range
      raise
    end

    def parse_percentage_sign
      value.to_f / 100.0
    end
  end
end
