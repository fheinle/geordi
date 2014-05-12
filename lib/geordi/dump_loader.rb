require 'rubygems'
require 'highline'


class DumpLoader

  def initialize(argv)
    @argv = argv
    @verbose = !!@argv.delete('-v')
  end

  def dumps_dir
    require 'etc'
    user_dir = Etc.getpwuid.dir
    File.join(user_dir, 'dumps')
  end

  def development_database_config
    require 'yaml'

    @config ||= YAML::load(ERB.new(File.read('config/database.yml')).result)
    @config['development']
  end
  alias_method :config, :development_database_config
  
  def mysql_command
    command = 'mysql --silent'
    command << ' -p' << config['password']
    command << ' -u' << config['username']
    command << ' --default-character-set=utf8'
    command << ' ' << config['database']
    command << ' < ' << dump_file
  end
  alias_method :mysql2_command, :mysql_command
  
  def postgresql_command
    command = 'pg_restore --no-owner --clean'
    command << ' --username=' << config['username']
    command << ' --host=' << config['host']
    command << ' --dbname=' << config['database']
    command << ' ' << dump_file
  end

  def source_dump!
    source_command = send("#{config['adapter']}_command")
    output = `#{source_command}`
      
    # return [normal lines, error lines]
    output.split($/).partition { |line| line !~ /^ERROR / }
  end

  def choose_dump_file
    highline = HighLine.new

    available_dumps = Dir.glob("#{dumps_dir}/*.dump").sort
    selected_dump = highline.choose(*available_dumps) do |menu|
      menu.hidden('') { exit }
    end
  end

  def dump_file
    @dump_file ||= if @argv[0] && File.exists?(@argv[0])
      @argv[0]
    else
      choose_dump_file
    end
  end

  def puts_info(msg = "")
    puts msg if @verbose
  end

  def execute
    puts_info "Sourcing #{dump_file} into #{config['database']} db ..."

    output, errors = source_dump!

    puts_info output.join($/) if output.any?

    if errors.empty?
      puts_info 'Successfully sourced the dump.'
      true
    else
      $stderr.puts "An error occured while loading the dump #{File.basename(dump_file)}"
      $stderr.puts errors.join($/);
      false
    end
  end

  def execute!
    if execute
      exit(0)
    else
      exit(1)
    end
  end

end

