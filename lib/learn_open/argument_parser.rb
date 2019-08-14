require 'optparse'

module LearnOpen
  class ArgumentParser
    attr_reader :args

    def initialize(args)
      @args = args
    end

    def parse
      options = {}
      rest = OptionParser.new do |opts|
        opts.on("--next", "open next lab") do |n|
          options[:next] = n
        end
        opts.on("--editor=EDITOR", "specify editor") do |e|
          options[:editor] = e
        end

        opts.on("--clone-only", "only download files. No shell") do |co|
          options[:clone_only] = co
        end

        opts.on("--lesson-uuid=UUID", "opens the lab by lesson uuid") do |uuid|
          options[:lesson_uuid] = uuid
        end
      end.parse(args)
      options[:lesson_name] = rest.first
      options
    end

    def learn_config_editor
      config_path = File.expand_path('~/.learn-config')
      editor = YAML.load(File.read(config_path))[:editor]
      editor.split.first
    end

    def empty?(val)
      val == '' || val.nil?
    end

    def execute
      cli_args = parse

      editor = empty?(cli_args[:editor]) ? learn_config_editor : cli_args[:editor]
      cli_args.merge!(editor: editor)

      [
        cli_args[:lesson_name],
        cli_args[:editor],
        cli_args[:next],
        cli_args[:clone_only],
        cli_args[:lesson_uuid]
      ]
    end
  end
end
