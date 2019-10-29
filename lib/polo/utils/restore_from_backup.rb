class RestoreFromBackup
  # TODO: ONLY WORKS WITH PG!!

  def initialize(temp_table: "tmp_restore_#{Date.today.to_s.gsub('-', '')}")
    @temp_table = temp_table
  end

  def connect_to_tmp!(&block)
    ActiveRecord::Base.establish_connection(adapter: 'postgresql', encoding: 'utf8', pool: 5, database: temp_table)
    yield
  ensure
    ActiveRecord::Base.establish_connection(Rails.env.to_sym)
  end

  def recreate_tmp_database!
    require 'pg'
    conn = PG.connect(dbname: 'template1')

    # Output a table of current connections to the DB
    if conn.exec("SELECT datname FROM pg_database WHERE datname = '#{temp_table}'").first
      puts "Dropping existing db #{temp_table}"
      conn.exec("DROP DATABASE #{temp_table}")
    end
    puts "Creating db #{temp_table}"
    conn.exec("CREATE DATABASE #{temp_table}")
  end

  # 2. import a dump into the tmp database
  def import_dump_into_tmp_database(backup_file:)
    puts "Importing dump #{backup_file} into #{temp_table}..."
    system "gunzip < #{Shellwords.escape(backup_file)} | psql #{temp_table}"
  end

  def restore_blob_if_missing_attachment(attachment)
    return if attachment.respond_to?(:attached?) && !attachment.attached?

    blob = attachment.blob
    blob.download
    puts " - Attachment #{blob.filename} still exists"
  rescue Aws::S3::Errors::NoSuchKey
    restore_blob(blob)
  end

  # restores a ActiveStorage::Blob from S3, when Versioning is enabled and only a Delete Marker is set
  def restore_blob(blob)
    @bucket ||= begin
                  s3_config = Rails.application.config.active_storage.service_configurations[Rails.application.config.active_storage.service.to_s]
                  s3 = Aws::S3::Resource.new(s3_config.except("service", "bucket").symbolize_keys)
                  s3.bucket(s3_config['bucket'])
                end
    puts " - Restoring s3 blob #{blob.filename} (AWS: #{blob.key})"
    versions = @bucket.object_versions(prefix: blob.key).to_a
    if versions.length > 0 && (dm = versions.find { |i| i.data.class == Aws::S3::Types::DeleteMarkerEntry })
      puts "  - removing delete marker"
      dm.delete
    else
      puts "  - no DeleteMarker found, can not restore!"
    end
  end

end
