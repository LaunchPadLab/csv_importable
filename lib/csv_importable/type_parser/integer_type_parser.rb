module CSVImportable
  class TypeParser::IntegerTypeParser < TypeParser
    def parse_val
      Integer(value)
    end

    def error_message
      "Invalid integer for column: #{key}"
    end
  end
end
