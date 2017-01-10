module CSVImportable
  class TypeParser::DateTypeParser < TypeParser
    def parse_val
      Date.new(year, month, day)
    end

    def year
      value[0..3].try(:to_i)
    end

    def month
      value[4..5].try(:to_i)
    end

    def day
      value[6..7].try(:to_i)
    end

    def error_message
      "Invalid date for column: #{key}"
    end
  end
end
