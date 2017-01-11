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

      has_attached_file :file
      validates_attachment :file, content_type: { content_type: ['text/csv']} , message: "is not in CSV format"
    end

    # === INTERFACE METHODS ===
    def self.importer_class
      # hook for subclasses
      CSVImportable::CSVImporter
    end

    def self.row_importer_class
      fail "row_importer_class class method is required by #{self.class.name}"
    end

    def read_file
      # returns CSV StringIO data
      # e.g. Paperclip.io_adapters.for(file).read
      fail "read_file method is required by #{self.class.name}"
    end

    def importable_class
      self.class
    end

    def save_to_db
      return save if respond_to?(:save)
      fail "please implement the save_to_db method on #{self.class.name}"
    end
    # === END INTERFACE METHODS ===

    def import!
      return start_async if should_run_async?
      process_now
    end

    def async_operation
      run_importer
    end

    def process_now
      run_importer
      complete!
    end

    def async_complete!
      complete!
    end

    def complete!
      return success! if importer.succeeded?
      failed!(results[:error])
    end

    def big_file?
      importer.big_file?
    end

    def should_run_async?
      big_file?
    end

    def not_running_async?
      !should_run_async?
    end

    def importer
      args = { should_replace: should_replace?, row_importer_class: self.class.row_importer_class }
      if new_record? && not_running_async?
        args = args.merge(file_string: read_file)
      else
        args = args.merge(import_id: id, importable_class: importable_class)
      end

      @importer ||= self.class.importer_class.new(args)
    end

    def underscored_pluralized_name
      underscored_name.pluralize
    end

    def underscored_name
      self.class.name.underscore
    end

    def error_hash
      return {} if did_not_fail?
      { underscored_name => formatted_errors }.with_indifferent_access
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
      results[:results].count
    end

    private

      def run_importer
        importer.import
        self.results = importer.results
      end
  end
end
