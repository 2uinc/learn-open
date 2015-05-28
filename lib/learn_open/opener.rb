module LearnOpen
  class Opener
    attr_reader   :editor, :client, :lessons_dir
    attr_accessor :lesson, :repo_dir, :lesson_is_lab, :lesson_id

    def self.run(lesson:, editor_specified:)
      new(lesson, editor_specified).run
    end

    def initialize(lesson, editor)
      _login, token = Netrc.read['learn-config']
      @client       = LearnWeb::Client.new(token: token)

      @lesson       = lesson
      @editor       = editor
      @lessons_dir  = YAML.load(File.read(File.expand_path('~/.learn-config')))[:learn_directory]
    end

    def run
      set_lesson

      if lesson_is_readme?
        open_readme
      else
        fork_repo
        clone_repo
        open_with_editor
        cd_to_lesson
      end
    end

    private

    def set_lesson
      if !lesson
        puts "Getting current lesson..."
        self.lesson        = get_current_lesson_forked_repo
        self.lesson_is_lab = current_lesson.lab
        self.lesson_id     = current_lesson.id
      else
        puts "Looking for lesson..."
        self.lesson        = ensure_correct_lesson.repo_slug
        self.lesson_is_lab = correct_lesson.lab
        self.lesson_id     = correct_lesson.lesson_id
      end

      self.repo_dir = lesson.split('/').last
    end

    def current_lesson
      @current_lesson ||= client.current_lesson
    end

    def get_current_lesson_forked_repo(retries=3)
      begin
        Timeout::timeout(15) do
          current_lesson.forked_repo
        end
      rescue Timeout::Error
        if retries > 0
          puts "There was a problem getting your lesson from Learn. Retrying..."
          get_current_lesson_forked_repo(retries-1)
        else
          puts "There seems to be a problem connecting to Learn. Please try again."
          exit
        end
      end
    end

    def ensure_correct_lesson
      correct_lesson
    end

    def correct_lesson(retries=3)
      @correct_lesson ||= begin
        Timeout::timeout(15) do
          client.validate_repo_slug(repo_slug: lesson)
        end
      rescue Timeout::Error
        if retries > 0
          puts "There was a problem connecting to Learn. Retrying..."
          correct_lesson(retries-1)
        else
          puts "Cannot connect to Learn right now. Please try again."
          exit
        end
      end
    end

    def fork_repo(retries=3)
      if !repo_exists?
        puts "Forking lesson..."
        begin
          Timeout::timeout(15) do
            client.fork_repo(repo_name: repo_dir)
          end
        rescue Timeout::Error
          if retries > 0
            puts "There was a problem forking this lesson. Retrying..."
            fork_repo(retries-1)
          else
            puts "There is an issue connecting to Learn. Please try again."
            exit
          end
        end
      end
    end

    def clone_repo(retries=3)
      if !repo_exists?
        puts "Cloning lesson..."
        begin
          Timeout::timeout(15) do
            Git.clone("git@github.com:#{lesson}.git", repo_dir, path: lessons_dir)
          end
        rescue Timeout::Error
          if retries > 0
            puts "There was a problem cloning this lesson. Retrying..."
            clone_repo(retries-1)
          else
            puts "Cannot clone this lesson right now. Please try again."
            exit
          end
        end
      end
    end

    def repo_exists?
      File.exists?("#{lessons_dir}/#{repo_dir}")
    end

    def open_with_editor
      if ios_lesson?
        open_ios_lesson
      elsif editor
        system("cd #{lessons_dir}/#{repo_dir} && #{editor} .")
      end
    end

    def ios_lesson?
      languages   = YAML.load(File.read("#{lessons_dir}/#{repo_dir}/.learn"))['languages']
      ios_lang    = languages.any? {|l| ['objc', 'swift'].include?(l)}

      ios_lang || xcodeproj_file? || xcworkspace_file?
    end

    def open_ios_lesson
      if can_open_ios_lesson?
        open_xcode
      else
        puts "You need to be on a Mac to work on iOS lessons."
        exit
      end
    end

    def can_open_ios_lesson?
      on_mac?
    end

    def open_xcode
      if xcworkspace_file?
        system("cd #{lessons_dir}/#{repo_dir} && open *.xcworkspace")
      elsif xcodeproj_file?
        system("cd #{lessons_dir}/#{repo_dir} && open *.xcodeproj")
      end
    end

    def xcodeproj_file?
      Dir.glob("#{lessons_dir}/#{repo_dir}/*.xcodeproj").any?
    end

    def xcworkspace_file?
      Dir.glob("#{lessons_dir}/#{repo_dir}/*.xcworkspace").any?
    end

    def cd_to_lesson
      puts "Opening lesson..."
      Dir.chdir("#{lessons_dir}/#{repo_dir}")
      bundle_install
      puts "Done."
      exec("#{ENV['SHELL']} -l")
    end

    def bundle_install
      # TODO: Don't bundle for other types of labs either
      if !ios_lesson?
        puts "Bundling..."
        system("bundle install &>/dev/null")
      end
    end

    def lesson_is_readme?
      !lesson_is_lab
    end

    def open_readme
      if can_open_readme?
        puts "Opening readme..."
        launch_browser
      else
        puts "You need to be running this on a Mac to open a Readme from the command line."
        exit
      end
    end

    def launch_browser
      if chrome_installed?
        open_chrome
      else
        open_safari
      end
    end

    def chrome_installed?
      File.exists?('/Applications/Google Chrome.app')
    end

    def open_chrome
      system("open -a 'Google Chrome' https://learn.co/lessons/#{lesson_id}")
    end

    def open_safari
      system("open -a Safari https://learn.co/lessons/#{lesson_id}")
    end

    def can_open_readme?
      on_mac?
    end

    def on_mac?
      !!RUBY_PLATFORM.match(/darwin/)
    end
  end
end
