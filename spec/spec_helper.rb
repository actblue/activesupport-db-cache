require 'bundler/setup'
require 'activesupport-db-cache'
require 'timecop'

require "sqlite3"

def setup_database(name)
  ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => name)
  ActiveRecord::Base.connection.create_table(:cache_items, :force => true) do |t|
    t.column :key, :string
    t.column :value, :text
    t.column :meta_info, :text
    t.column :expires_at, :datetime
    t.column :created_at, :datetime
    t.column :updated_at, :datetime
  end
  ActiveRecord::Base.connection.add_index(:cache_items, :key, :unique => true)
  ActiveRecord::Base.connection.add_index(:cache_items, :created_at)
  ActiveRecord::Base.connection.add_index(:cache_items, :updated_at)
end

setup_database 'db/test_alternate.sqlite3'
setup_database 'db/test.sqlite3'

# logfile_dir = File.expand_path("../../log", __FILE__)
# Dir.mkdir(logfile_dir) unless File.exists?(logfile_dir)
# logfile = File.open("#{logfile_dir}/test.log", 'a')
# ActiveRecord::Base.logger = Logger.new(logfile)

Dir['./spec/support/*.rb'].map {|f| require f }

RSpec.configure do |config|
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
end
