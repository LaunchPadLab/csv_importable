module CSVImportable
  class TypeParser::FloatTypeParser < TypeParser
    def parse_val
      Float(value)
    end

    def error_message
      "Invalid decimal for column: #{key}"
    end
  end
end
