module CSVImportable
  class TypeParser
    attr_reader :row, :key, :value, :required

    def initialize(key, args = {})
      @key = key
      @row = args[:row]
      @required = args.fetch(:required, false)
      @value = args.fetch(:value, pull_value_from_row)
      after_init(args)
    end

    def parse
      if value.blank?
        check_required
        return nil
      end
      parsed_val = nil
      begin
        parsed_val = parse_val
      rescue
        raise_parsing_error
      end
      raise_parsing_error if parsed_val.nil?
      parsed_val
    end

    private

    def after_init(args)
      # hook for subclasses
    end

    def pull_value_from_row
      return nil unless row
      # handle both caps and lowercase
      row.field(key) || row.field(key.upcase) || row.field(key.downcase)
    end

    def parse_val
      # hook for subclasses
      fail 'parse_val is a required method for subclass'
    end

    def raise_parsing_error
      raise error_message
    end

    def error_message
      fail 'error_message is a requird method for subclass'
    end

    def raise_required_error
      raise required_error_message
    end

    def required_error_message
      "#{key} is blank"
    end

    def required?
      required
    end

    def check_required
      return raise_required_error if required?
    end
  end
end

require_relative './type_parser/boolean_type_parser'
require_relative './type_parser/date_type_parser'
require_relative './type_parser/float_type_parser'
require_relative './type_parser/integer_type_parser'
require_relative './type_parser/percent_type_parser'
require_relative './type_parser/select_type_parser'
require_relative './type_parser/string_type_parser'
require_relative './type_parser/us_zip_type_parser'
