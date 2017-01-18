require "asyncable"

module CSVImportable
  module Importable
    # columns: results (text), file (attachment),
    #          should_replace (boolean), type (string),
    #          status (string)

    include Asyncable
    extend ActiveSupport::Concern

    included do
      serialize :results, Hash
    end

    DEFAULT_BIG_FILE_THRESHOLD = 10

    # === PUBLIC INTERFACE METHODS ===
    def read_file
      # returns CSV StringIO data
      # e.g. Paperclip.io_adapters.for(file).read
      fail "read_file method is required by #{self.class.name}"
    end


    def save_to_db
      return save if respond_to?(:save)
      fail "please implement the save_to_db method on #{self.class.name}"
    end
    # === END INTERFACE METHODS ===

    def import!
      # start_async provided by Asyncable module
      return start_async if run_async?
      process_now
    end

    def run_async?
      big_file?
    end

    def not_async?
      !run_async?
    end

    def formatted_errors
      @formatted_errors ||= (
        errors = []
        error_key = CSVImportable::CSVImporter::Statuses::ERROR
        errors << results.fetch(error_key) if results.has_key?(error_key)
        errors + results.fetch(:results, [])
          .select { |result| result.fetch(:status) == error_key }
          .map    { |error| "Line #{error.fetch(:row)}: #{error.fetch(:errors).join(', ')}" }
      )
    end

    def display_status
      case status
      when Statuses::SUCCEEDED
        'Import Succeeded'
      when Statuses::FAILED
        'Import Failed with Errors'
      else
        'Processing'
      end
    end

    def number_of_records_imported
      return 0 unless results && results.is_a?(Hash)
      results[:results].try(:count) || 0
    end

    private

      # === PRIVATE INTERFACE METHODS ===
      def importer_class
        # hook for subclasses
        CSVImportable::CSVImporter
      end

      def row_importer_class
        fail "row_importer_class class method is required by #{self.class.name}"
      end

      def importable_class
        self.class
      end

      def importer_options
        # hook for additional options
        {}
      end
      # === END INTERFACE METHODS ===

      def async_operation
        run_importer
      end

      def process_now
        run_importer
        complete!
      end

      def async_complete!
        # async_complete! is a hook from Asyncable module
        complete!
        after_async_complete
      end

      def complete!
        return success! if importer.succeeded?
        failed!(results[:error])
      end

      def big_file?
        importer.big_file?
      end

      def big_file_threshold
        DEFAULT_BIG_FILE_THRESHOLD
      end

      def importer
        return @importer if @importer

        args = {
          should_replace: should_replace?,
          row_importer_class: row_importer_class,
          big_file_threshold: big_file_threshold
        }.merge(importer_options)

        if new_record? && !processing? # e.g. new record that's not async
          args = args.merge(file_string: read_file)
        else
          args = args.merge(import_id: id, importable_class: importable_class)
        end

        @importer ||= importer_class.new(args)
      end

      def run_importer
        importer.import
        self.results = importer.results
      end
  end
end
