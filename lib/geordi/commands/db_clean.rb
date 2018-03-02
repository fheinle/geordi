desc 'drop-databases', 'Delete local non-whitelisted databases'
long_desc <<-LONGDESC

Drop non-whitelisted databases from local installations of MySQL/MariaDB and
  PostgreSQL. Offers to edit the whitelist.
LONGDESC

option :postgres_only, :aliases => '-P', :type => :boolean,
  :desc => 'Only clean Postgres', :default => false
option :mysql_only, :aliases => '-M', :type => :boolean,
  :desc => 'Only clean MySQL/MariaDB', :default => false
option :postgres, :banner => 'STRING',
  :desc => 'Use Postgres port or socket'
option :mysql, :banner => 'STRING',
  :desc => 'Use MySQL/MariaDB port or socket'

def drop_databases
  require 'geordi/db_cleaner'
  cleaner = DBCleaner.new
  fail '-P and -M are mutually exclusive' if options.postgres_only and options.mysql_only
  unless options.postgres_only
    mysql_flags = nil
    unless options.mysql.nil?
      begin
        mysql_port = Integer(options.mysql)
        mysql_flags = "--port=#{mysql_port} --protocol=TCP"
      rescue AttributeError
        unless File.exist? options.mysql
          fail "Path #{options.mysql} is not a valid MySQL socket"
        end
        mysql_flags = "--socket=#{options.mysql}"
      end
    end
    cleaner.clean_mysql(mysql_flags)
  end

  unless options.mysql_only
    postgres_flags = nil
    unless options.postgres.nil?
      postgres_flags = "--port=#{options.postgres}"
    end
    cleaner.clean_postgres(postgres_flags)
  end
  # For formatted output, see geordi/interaction.rb
  success 'Done.'
end

