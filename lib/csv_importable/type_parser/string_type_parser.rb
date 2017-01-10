module CSVImportable
  class TypeParser::StringTypeParser < TypeParser
    def parse_val
      value
    end

    def error_message
      "Invalid string for column: #{key}"
    end
  end
end
