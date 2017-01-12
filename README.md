# CSV Importable

Intelligently parse CSVs and display errors to your users.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'csv_importable'
```

And then execute:

    $ bundle

## Usage

High level steps:

1. Create an `Import` model: this model handles and stores the file, status, and results of the import for the user to see.
2. Create a `RowImporter` class: this class handles the logic surrounding how one row in the CSV should be added to the database.

Please note, it is also possible to implement an `Importer` class, which handles the logic surrounding how the entire file is imported. This is not usually needed though.


### Create Import Model

This model handles and stores the file, status, and results of the import for the user to see. By storing the file and results, we can process the import in the background when the file is too large to process real-time, and then email the user when the import is finished.

Note: if you're not using Paperclip, you can modify `file` to be a string or some other data type that helps you find the file for the `read_file` method, which is really the only required field as it relates to the uploaded file.

    $ rails g model Import status:string results:text type:string file:attachment should_replace:boolean
    $ bundle exec rake db:migrate

Change the Import class to look something like below:

```ruby
class Import < ActiveRecord::Base
  include CSVImportable::Importable

  def row_importer_class
    # e.g. UserRowImporter (see next section)
  end

  def read_file
    # needs to return StringIO of file
    # for paperclip, use:
    # Paperclip.io_adapters.for(file).read
  end

  def after_async_complete
    # this is an optional hook for when an async import finishes
    # e.g. SiteMailer.import_completed(import).deliver_later
  end

  def save_to_db
    save
  end

  def big_file_threshold
    # max number of rows before processing with a background job
    # super returns the default of 10
    super
  end
end
```

### Create RowImporter Class

this class handles the logic surrounding how one row in the CSV should be added to the database. You need only (1) inherit from `CSVImportable::CSVImporter` and (2) implement the `import_row` method.

```ruby
class UserRowImporter < CSVImportable::CSVImporter
  def import_row
    user = User.new
    user.email = pull_string('email', required: true)
    user.first_name = pull_string('first_name', required: true)
    user.last_name = pull_string('last_name', required: true)
    user.birthdate = pull_date('birthdate') # format: YYYYMMDD    
    user.salary = pull_float('salary')
  end
end
```

#### Parsers

To assist you in getting data out of your CSV, we've implemented some basic parsers. These parsers will grab the raw data for the particular row/column and attempt to coerce it into the correct type (e.g. take string from CSV and convert to float).

If the parser fails to coerce the data properly, it will add an error message to the array of errors that your user receives after the import runs. These errors help the user fix the import file in order to try again.

- pull_string
- pull_boolean
- pull_date
- pull_float
- pull_integer
- pull_select

Basic syntax: `pull_string(column_key, args)` where `column_key` is the CSV header string for the column and `args` is a hash with the following defaults: `{ required: false }`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/launchpadlab/csv_importable

