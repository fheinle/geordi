desc 'drop-databases', 'Delete local non-whitelisted databases'
long_desc <<-LONGDESC

Drop non-whitelisted databases from local installations of MySQL/MariaDB and
  PostgreSQL. Offers to edit the whitelist.
LONGDESC

def drop_databases
  require 'geordi/db_cleaner'
  cleaner = DBCleaner.new
  cleaner.clean_mysql
  cleaner.clean_postgres

  # For formatted output, see geordi/interaction.rb
  success 'Done.'
end

