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

1. Create an `Import` model: this model stores the file, status, and results of the import for the user to see.
2. Create a `RowImporter` class: this class handles the logic surrounding how one row in the CSV should be imported.
3. Create route(s), controller, and view(s) to allow your users to upload a CSV and return comprehensive, easy to understand error messages for your users to correct the CSV and re-upload.

Please note, it is also possible to implement an `Importer` class, which handles the logic surrounding how the entire file is imported. This is not usually needed though as our default `Importer` will take care of the heavy lifting.

If any errors happen during the upload process, they are recorded, stored, and ultimately displayed to the user for an opportunity to correct the CSV file.

### Create Import Model

This model handles and stores the file, status, and results of the import for the user to see. By storing the file and results, we can process the import in the background when the file is too large to process real-time, and then email the user when the import is finished.

Note: if you're not using Paperclip, don't worry about implementing the `file` field. The important thing is that you implement a `read_file` method on your `Import` class so we know how to get the StringIO data for your CSV file.

    $ rails g model Import status:string results:text type:string file:attachment should_replace:boolean
    $ bundle exec rake db:migrate

Change the Import class to look something like below:

```ruby
class Import < ActiveRecord::Base
  include CSVImportable::Importable

  has_attached_file :file
  validates_attachment :file, content_type: { content_type: ['text/csv']}, message: "is not in CSV format"

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

And then create a subclass that should correspond to the specific importing task you are implementing. For example, if you are trying to import users from a CSV, you might implement a `UserImport` class which inherits from `Import`:

```ruby
class UserImport < Import
  def row_importer_class
    UserRowImporter
  end
end
```

The only method that you need to define here is the `row_importer_class`, which tells `csv_importable` how to import each row in the CSV. Let's take a look.

### Create RowImporter Class

The `RowImporter` class handles the logic surrounding how one row in the CSV should be imported and added to the database. You need only (1) inherit from `CSVImportable::CSVImporter` and (2) implement the `import_row` method.

```ruby
class UserRowImporter < CSVImportable::CSVImporter
  def import_row
    user = User.create(
      email: pull_string('email', required: true),
      first_name: pull_string('first_name', required: true),
      last_name: pull_string('last_name', required: true),
      birthdate: pull_date('birthdate'), # format: YYYYMMDD
      salary: pull_float('salary')
    )
  end
end
```

See that `pull_string` method? Let's talk about that for a second...

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


#### Custom Parsers

You can build a custom parser by creating a class that inherits from `CSVImportable::TypeParser`. This class needs to implement at least two methods:

- `parse_val`
- `error_message`

For example:

```ruby
class TypeParser::CustomDateTypeParser < CSVImportable::TypeParser
  def parse_val
    Date.strptime(value, '%m-%d-%Y')
  end

  def error_message
    "Invalid date for column: #{key}"
  end
end
```

Now, in your `RowImporter` class you can call: `TypeParser::CustomDateTypeParser.new('my_date_field')` to return a date object when the data is in the right format. If the parser fails to parse the field, it will add the correct error message for your user to review and resolve.

#### Ignoring Parsers

Inside a `RowImporter` class, you have access to `row` and `headers` methods. For example, you can call `row.field('field_name')` to pull data directly from the CSV. 

### Creating an Import UI for your users

Let's say you want to create a UI for your users to upload a CSV of users for your new `UserImport`.

Routes:

```ruby
resources :user_imports, only: [:new, :create, :index], controller: :user_imports
```

Controller:

```ruby
class UserImportsController < ApplicationController
  def new
    @import = UserImport.new
  end

  def create
    @import = UserImport.new(args)

    if @import.import!
      redirect_to :back, notice: "The file is being imported."
    else
      redirect_to :back, alert: 'There was a problem with the import. Please contact the administrator if the probelm persists.'
    end
  end

  def index
    @imports = UserImport.all
  end
end
```

Your form view may look something like:

```erb
<%= form_for @import, html: { multipart: true } do |f| %>
  <% if f.object.failed? %>
    <ul>
      <% f.object.formatted_errors.each do |error| %>
        <li><%= error %></li>
      <% end %>
    </ul>
  <% end %>

  <%= f.file_field :file %>
  <%= f.submit %>
<% end %>
```

Your index view may look something like:

```erb
<ul>
  <% @imports.each do |import| %>
    <li>
      <p>Status: <%= import.display_status %></p>
      <p>Number of Records: <%= import.number_of_records_imported %></p>
      <% if import.failed? %>
        <p>Errors:</p>
        <ul>
          <% import.formatted_errors.each do |error| %>
            <li><%= error %></li>
          <% end %>
        </ul>
      <% end %>
    </li>
  <% end %>
</ul>
```

### ActiveAdmin

If you are using ActiveAdmin, consider adding the code below for your admin/import.rb file:

```ruby
ActiveAdmin.register Import do
  config.filters = false

  index do
    column 'Status' do |import|
      link_to import.display_status, admin_import_path(import)
    end
    column 'File Uploaded' do |import|
      link_to import.file_file_name, import.file.url
    end
    column 'Records' do |import|
      import.number_of_records_imported
    end
    actions
  end

  show do
    attributes_table do
      row 'Status' do |import|
        import.display_status
      end
      row 'Errors' do |import|
        if import.failed?
          ul do
            import.formatted_errors.each do |error|
              li style: 'color:red;' do
                error
              end
            end
          end
        else
          'None'
        end
      end
      row 'File Uploaded' do |import|
        link_to import.file_file_name, import.file.url
      end
      row 'Records Imported' do |import|
        import.number_of_records_imported
      end
    end
  end

  form :html => { :enctype => "multipart/form-data" } do |f|
    if f.object.failed?
      panel "Errors" do
        ul do
          f.object.formatted_errors.each do |error|
            li style: 'color:red;' do
              error
            end
          end
        end
      end
    end

    f.inputs "Details" do
      f.input :file, :as => :file, :hint => f.object.file_file_name
    end
    f.actions
  end

  controller do
    def process_success
      notice = @import.processing? ? 'Your import is being processed' : 'Your import is complete'
      redirect_to admin_import_path(@import), notice: notice
    end

    def create
      @import = Import.new(params[:import])

      if @import.import!
        process_success
      else
        return render :new
      end
    end

    def update
      @import = Import.find(params[:id])
      @import.attributes = params[:import] || {}

      if @import.import!
        process_success
      else
        return render :edit
      end
    end
  end
end
```


#### One UI to rule them all

For the ambitous out there that are trying to build one common UI for your users to implement many different imports, see here.

Routes:

```
resources :user_imports, controller: :imports, type: 'UserImport'
resources :companies_imports, controller: :imports, type: 'CompanyImport'
```

Controller:

```
class ImportsController < ApplicationController
  def index
    @imports = model.all
  end

  def new
    @import = model.new
  end

  def create
    @import = model.new(args)

    if @import.import!
      redirect_to :back, notice: "The file is being imported."
    else
      redirect_to :back, alert: 'There was a problem with the import. Please contact the administrator if the probelm persists.'
    end
  end

  def edit
    @import = model.find(params[:id])
  end

  def show
    @import = model.find(params[:id])
  end

  private

    def type
      params.fetch(:type, 'Import')
    end

    def model
      # see below for ensuring this import type is present
      # and then uncomment the following line:
      # raise 'Not a valid import type' unless valid_type?
      type.constantize
    end

    # need to implement an array of available types
    # in Import class for this to work:
    # def valid_type?
    #   Import::Types::ALL.include?(type)
    # end
    
    # def redirect_invalid_type
    #   flash.now[:alert] = 'Not a valid import type'
    #   return redirect_to :back
    # end
end
```

app/helpers/imports_helper:

```
module ImportsHelper
  def url_for_import(import_obj)
    if import_obj.new_record?
      name = import_obj.class.name.underscore.pluralize
      send("#{name}_path")
    else
      name = import_obj.class.name.underscore.pluralize
      send("#{name}_path", import_obj)
    end
  end
end
```

Your view may look something like:

```
<%= form_for @import, url: url_for_import(@import), html: { multipart: true } do |f| %>
  <%= f.file_field :file %>
  <%= f.submit %>
<% end %>
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/launchpadlab/csv_importable

