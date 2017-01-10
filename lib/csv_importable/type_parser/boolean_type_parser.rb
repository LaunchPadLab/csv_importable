module CSVImportable
  class TypeParser::BooleanTypeParser < TypeParser
    def parse_val
      val = true if ["yes", "y", true, "true"].include?(value.downcase)
      val = false if ["no", "n", false, "false"].include?(value.downcase)
      val
    end

    def error_message
      "Invalid boolean for column: #{key}"
    end
  end
end
