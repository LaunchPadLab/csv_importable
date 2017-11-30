module CSVImportable
  class TypeParser::ZipTypeParser < TypeParser
    def parse_val
      not_digits unless value.count('0-9') == value.length
      value = '0' + value until value.length >= 5
      value
    end

    def not_digits
      raise
    end

    def error_message
      "Invalid value for column: #{key}"
    end
  end
end
