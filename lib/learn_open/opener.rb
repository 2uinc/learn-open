module LearnOpen
  class Opener
    attr_reader :editor,
                :target_lesson,
                :get_next_lesson,
                :clone_only,
                :lesson_uuid,
                :io,
                :logger,
                :options

    def self.run(lesson:, editor_specified:, get_next_lesson:, clone_only:, lesson_uuid:)
      new(lesson, editor_specified, get_next_lesson, clone_only, lesson_uuid: lesson_uuid).run
    end

    def initialize(target_lesson, editor, get_next_lesson, clone_only, options)
      @target_lesson = target_lesson
      @editor = editor
      @get_next_lesson = get_next_lesson
      @clone_only = clone_only
      @lesson_uuid = options[:lesson_uuid]

      @io = options.fetch(:io, LearnOpen.default_io)
      @logger = options.fetch(:logger, LearnOpen.logger)

      @options = options
    end

    def run
      logger.log('Getting lesson...')
      io.puts "Looking for lesson..."

      learn_web_adapter = LearnOpen::Adapters::LearnWebAdapter.new(options)

      lesson_data = if lesson_uuid
                      learn_web_adapter.fetch_two_u_lesson(lesson_uuid)
                    else
                      learn_web_adapter.fetch_lesson_data(
                        target_lesson: target_lesson,
                        fetch_next_lesson: get_next_lesson
                      )
                    end

      lesson = Lessons.classify(lesson_data, options)
      environment = LearnOpen::Environments.classify(options)
      lesson.open(environment, editor, clone_only)
    end
  end
end
