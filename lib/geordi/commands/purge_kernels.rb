# This file serves as a template for adding new commands.
# For more inspiration, see already implemented commands.

# Since commands can be invoked by only typing their first letters, please try
# to find a command name that has a unique prefix.

desc 'purge-kernels ARG [OPTIONAL]', 'one-line description'
long_desc <<-LONGDESC # optional
Start with an example: `command bla bla`

Detailed description with anything the user needs to know.

Short and long description are printed on the console AND included in the README
by `rake update_readme`. Thus, please format descriptions in a way that's reader
friendly both in Markdown and the console.
LONGDESC

# option :opt, :type => :boolean, :aliases => '-o', :banner => 'VALUE_NAME',
#        :desc => 'If set, VALUE_NAME will be used for something'

def purge_kernels
  kernels = Util.retrieve_kernels

  announce 'Purging old kernels'
  note 'Current kernel: ' + kernels[:current]
  if kernels[:old].any?
    note ['Old kernels:', *kernels[:old].reverse].join "\n"

    warn 'To remove these old kernels, run this command as super user: '
    note_cmd 'apt-get purge ' + kernels[:old].join(' ')
  else
    success 'No old kernels found.'
  end
  #
  #
  # # Invoke other commands like this:
  # invoke_cmd 'other_command', 'argument', :an => 'option'
  #
  # fail 'Option missing' unless options.opt?
  #
  # # For formatted output, see geordi/interaction.rb
  # success 'Done.'
end
