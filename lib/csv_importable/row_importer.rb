module CSVImportable
  class RowImporter
    include CSVImportable::CSVCoercion
    attr_reader :row, :headers

    def initialize(args = {})
      @row = args[:row]
      @headers = args[:headers]
      after_init(args)
    end

    def import_row
      # hook for subclasses
    end

    private

      def after_init(args)
        # hook for subclasses
      end
  end
end
