require 'fileutils'
require 'socket'
require 'open3'

module Geordi
  class DBCleaner
    include Geordi::Interaction

    def initialize
      base_directory = ENV['XDG_CONFIG_HOME']
      base_directory = "#{Dir.home}" if base_directory.nil?
      @whitelist_directory = File.join(base_directory, '.config', 'geordi', 'whitelists')
      FileUtils.mkdir_p(@whitelist_directory) unless File.directory? @whitelist_directory
    end

    def edit_whitelist(dbtype)
      whitelist = whitelist_fname(dbtype)
      texteditor = choose_texteditor
      system("#{texteditor} #{whitelist}")
    end

    def create_new_whitelist(dbtype)
      whitelist = whitelist_fname(dbtype)
      return if File.exist? whitelist
      File.open(whitelist, 'w') do |wl|
        wl.write('# System databases are always whitelisted')
      end
    end

    def clean_mysql(extra_flags)
      announce 'Dropping MySQL and MariaDB databases'
      note 'Trying to authenticate using system root account (for MariaDB and MySQL from recent Oracle repos)'
      unless extra_flags.nil?
        if extra_flags.include? 'port'
          port = Integer(extra_flags.split('=')[1].split()[0])
          fail "Port #{port} is not open" unless is_port_open? port
        end
      end
      mysql_command = 'sudo mysql'
      mysql_command << " #{extra_flags}" unless extra_flags.nil?
      Open3.popen3("#{mysql_command} -e 'QUIT'") do |stdin, stdout, stderr, thread|
        break if thread.value.exitstatus == 0
        mysql_error = stderr.read.lines[0].chomp.strip.split[1]
        if mysql_error == '1045'
          note 'System authentication failed (no problem!), trying MySQL authentication'
          mysql_command = 'mysql -uroot'
          mysql_command << " #{extra_flags}" unless extra_flags.nil?
          unless File.exist? File.join(Dir.home, 'my.cnf')
            warn 'You do not have $HOME/.my.cnf. You will have to enter your MySQL root password a lot!'
            mysql_command << ' -p'
          end
          Open3.popen3("#{mysql_command} -e 'QUIT'") do |stdin2, stdout2, stderr2, thread2|
            fail 'Could not connect to MySQL/MariaDB' unless thread2.value.exitstatus == 0
          end
        elsif mysql_error == '2013'
          fail 'MySQL/MariaDB connection failed, is this the correct port?'
        end
      end
      database_list = list_all_mysql_dbs(mysql_command)
      # confirm_deletion includes option for whitelist editing
      deletable_dbs = confirm_deletion('mysql', database_list)
      return if deletable_dbs.nil?
      deletable_dbs.each do |db|
        `#{mysql_command} -e 'DROP DATABASE \`#{db}\`;'`
      end
    end

    def clean_postgres(extra_flags)
      announce 'Dropping PostgreSQL databases'
      postgres_command = 'sudo -u postgres psql'
      unless extra_flags.nil?
        begin
          port = Integer(extra_flags.split('=')[1])
          fail "Port #{port} is not open" unless is_port_open? port
        rescue ArgumentError
          socket = extra_flags.split('=')[1]
          fail "Socket #{socket} does not exist" unless File.exist? socket
        end
        postgres_command << " #{extra_flags}"
      end
      Open3.popen3("#{postgres_command} -c ';'") do |stdin, stdout, stderr, thread|
        fail 'Could not connect to PostgreSQL' unless thread.value.exitstatus == 0
      end
      database_list = `#{postgres_command} -t -A -c 'SELECT DATNAME FROM pg_database WHERE datistemplate = false;'`.split
      deletable_dbs = confirm_deletion('postgres', database_list)
      return if deletable_dbs.nil?
      deletable_dbs.each do |db|
        note "Dropping database `#{db}`."
        `#{postgres_command} -c 'DROP DATABASE "#{db}";'`
      end
    end

    def list_all_mysql_dbs(mysql_command)
      `#{mysql_command} -B -N -e 'show databases'`.split
    end
    private :list_all_mysql_dbs

    def whitelist_fname(dbtype)
      File.join(@whitelist_directory, dbtype) << '.yaml'
    end

    def confirm_deletion(dbtype, database_list)
      proceed = ''
      until %w[y n].include? proceed
        deletable_dbs = filter_whitelisted(dbtype, database_list)
        if deletable_dbs.empty?
          note "No #{dbtype} databases found that were not whitelisted"
          if prompt('Edit the whitelist? [y]es or [n]o') == 'y'
            proceed = 'e'
          else
            return []
          end
        end
        if proceed.empty?
          note "The following #{dbtype} databases are not whitelisted and will be deleted:"
          deletable_dbs.sort.each do |db|
            note db
          end
          proceed = prompt('Proceed? [y]es, [n]o or [e]dit whitelist')
        end
        case proceed
        when 'e'
          proceed = ''  # reset user selection
          edit_whitelist dbtype
        when 'n'
          announce 'Not deleting anything'
          return []
        when 'y'
          return deletable_dbs
        end
      end
    end
    private :confirm_deletion

    def create_whitelist(dbtype)
      whitelist = File.open(whitelist_fname(dbtype), 'w')
      if dbtype == 'mysql'
        whitelist.write("# Always whitelisted:\n# information_schema\n# performance_schema\n# mysql\n# sys\n")
      elsif dbtype == 'postgres'
        whitelist.write("# Always whitelisted: \n # postgres\n")
      end
      whitelist.write("# When you whitelist `foo`, `foo_development` and `foo_test\d?` will be considered whitelisted, too.")
      whitelist.close
    end

    def filter_whitelisted(dbtype, database_list)
      create_whitelist(dbtype) unless File.exist? whitelist_fname(dbtype)
      protected = {
        'mysql'    => %w[mysql information_schema performance_schema sys],
        'postgres' => ['postgres'],
      }
      whitelist_content = File.open(whitelist_fname(dbtype), 'r').read.lines.map(&:chomp).map(&:strip)
      # n.b. `delete` means 'delete from list of dbs that should be deleted in this context
      # i.e. `delete` means 'keep this database'
      deletable_dbs = database_list.dup
      deletable_dbs.delete_if { |db| whitelist_content.include? db.sub(/_(test\d?|development)$/, '') }
      deletable_dbs.delete_if { |db| protected[dbtype].include? db }
      deletable_dbs.delete_if { |db| db.start_with? '#' }
    end
    private :filter_whitelisted
  end
end

def choose_texteditor
  %w[$VISUAL $EDITOR /usr/bin/editor vi].each do |texteditor|
    return texteditor if cmd_exists? texteditor
  end
end

def cmd_exists? cmd
  system("which #{cmd} > /dev/null")
  return $?.exitstatus.zero?
end

def is_port_open?(port)
  begin
    socket = TCPSocket.new('127.0.0.1', port)
    socket.close
    return true
  rescue Errno::ECONNREFUSED
    return false
  end
end
