module CSVImportable
  module CSVCoercion
    def string_type_class
      CSVImportable::TypeParser::StringTypeParser
    end

    def date_type_class
      CSVImportable::TypeParser::DateTypeParser
    end

    def boolean_type_class
      CSVImportable::TypeParser::BooleanTypeParser
    end

    def integer_type_class
      CSVImportable::TypeParser::IntegerTypeParser
    end

    def float_type_class
      CSVImportable::TypeParser::FloatTypeParser
    end

    def percent_type_class
      CSVImportable::TypeParser::PercentTypeParser
    end

    def select_type_class
      CSVImportable::TypeParser::SelectTypeParser
    end

    [:string, :date, :boolean, :integer, :float, :percent, :select].each do |parser_type|
      define_method("pull_#{parser_type}") do |key, options={}|
        csv_row = options.fetch(:row, @row)
        options = options.merge(row: csv_row)
        parser = send("#{parser_type}_type_class").new(key, options)
        parser.parse
      end
    end
  end
end
