module CSVImportable
  class TypeParser::SelectTypeParser < TypeParser
    attr_reader :options

    def after_init(args = {})
      @options = args.fetch(:options, [])
    end

    def parse_val
      val = value.downcase
      raise unless options.include?(val)
      val
    end

    def error_message
      "Invalid value for column: #{key}. Must be one of the following: #{options.join(', ')}"
    end
  end
end
