require 'pronto'

module Pronto
  class Envcheck < Runner
    CHECKS = [/ENV\[('|"):?(\w+?)('|")\]/].freeze

    def run
      return [] unless @patches

      @patches
        .select { |patch| patch.additions > 0 }
        .map { |patch| inspect(patch) }
        .flatten.compact
    end

    private

    def git_repo_path
      @git_repo_path ||= Rugged::Repository
                         .discover(File.expand_path(Dir.pwd))
                         .workdir
    end

    def readme
      @readme ||= File.read("#{git_repo_path}/README.md")
    end

    def inspect(patch)
      offending_line_numbers(patch).map do |line_number|
        patch
          .added_lines
          .select { |line| line.new_lineno == line_number }
          .map do |line|
            new_message('Environment variable missing in README', line)
          end
      end
    end

    def offending_line_numbers(patch)
      line_numbers = []

      Dir.chdir(git_repo_path) do
        File.foreach(patch.new_file_full_path.to_s).with_index do |line, line_num|
          line_numbers << line_num + 1 if missing_env?(line)
        end
        line_numbers
      end
    end

    def missing_env?(line)
      CHECKS.any? do |check|
        match = check.match(line)

        (match && !(readme.include? match[2] ))
      end
    end

    def new_message(offence, line)
      path = line.patch.delta.new_file[:path]
      level = :warning

      Message.new(path, line, level, offence, nil, self.class)
    end
  end
end
