# Polo::Utils

This library wraps common needed functionality of the [awesome Polo Gem](https://github.com/IFTTT/polo) to ease the following usecases:

1. export a model with ALL associations up to a specific depth
2. restore deleted items: importing a backup sql.zip into a temporary database, connects to it, run Polo for the user/object, importing the dump into the production database


NOTICE: If you are needing postgresql support, try our fork, which implements PG upserts: https://github.com/pludoni/polo

```
gem 'polo', git: 'https://github.com/pludoni/polo.git'
gem 'polo-utils', git: 'https://github.com/pludoni/polo-utils.git'
```

## 1. Exporting a model with all associations


e.g. create script (e.g. bin/extract_user)

```ruby
#!/usr/bin/env ruby
if ARGV.length == 0
  $stderr.puts "USAGE: #{__FILE__} [user_id]
  exit 1
end

APP_PATH = File.expand_path('../config/application', __dir__)
require_relative '../config/boot'
require_relative '../config/environment.rb'
require 'polo/utils'

user_id = ARGV[0]

sqls = Polo::Utils.extract(User, user_id, max_level: 3, blacklist: [:versions])
puts sqls
```

then you can run the script and pipe the sql output:

```bash
bundle exec bin/extract_user 1 | gzip > dump.sql.gz
```

...download and reimport into your development database.

## 2. Restoring deleted objects

NOTE: Only implemented with PG.
For this to work, we need a database snapshot from before the deletion. Locate it, upload to a app server, and then create a script:

```ruby
require 'polo/utils/restore_from_backup'

# drop/recreate database
runner = Polo::Utils::RestoreFromBackup.new(temp_table: "tmp_restore_#{Date.today.to_s.gsub('-', '')}")
runner..recreate_tmp_database!
runner.import_dump_into_tmp_database(backup_file: '/var/backup/.../*.sql.gz')
sql = []
runner.connect_to_tmp! do
  # sql = Polo.explore(User, id.to_i, associations)
  sql = Polo::Utils.extract(User, user_id, max_level: 1, blacklist: [:versions])
end
sql.each do |statement|
  puts " - executing #{statement.slice(0, 200) + "..."}"
  ActiveRecord::Base.connection.execute(statement)
end

# optional: restore S3-Blobs when they have versioning enabled (DeleteMarker)
User.find(id).attachments.each do |attachment|
  runner.restore_blob_if_missing_attachment(attachment)
end
runner.restore_blob_if_missing_attachment(User.find(id).logo)
```


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
