# frozen_string_literal: true

# This class validates the changed files in a pull request, and performs
# several checks during this process:
#
#  - schema validation for all current projects
#  - tag validation
#  - directory structure validation
#
class PullRequestValidator
  PREAMBLE_HEADER = '<!-- PULL REQUEST ANALYZER GITHUB ACTION -->'

  GREETING_HEADER = ":wave: I'm a robot checking the state of this pull request to save the human reveiwers time." \
  " I noticed this PR added or modififed the data files under `_data/projects/` so I had a look at what's changed.\n\n" \
  "As you make changes to this pull request, I'll re-run these checks."

  UPDATE_HEADER = 'Checking the latest changes to the pull request...'

  def self.generate_comment(dir, files, initial_message: true)
    projects = files.map do |f|
      full_path = File.join(dir, f)

      Project.new(f, full_path) if File.exist?(full_path)
    end

    projects.compact!

    markdown_body = "#{PREAMBLE_HEADER}\n\n" + get_header(initial_message) + "\n\n"

    projects_without_valid_extensions = projects.reject { |p| File.extname(p.relative_path) == '.yml' }

    if projects_without_valid_extensions.any?
      messages = ['#### Unexpected files found in project directory']
      projects_without_valid_extensions.each do |p|
        messages << " - `#{p.relative_path}`"
      end
      messages << 'All files under `_data/projects/` must end with `.yml` to be listed on the site'
    elsif projects.count > 2
      results = projects.map { |p| review_project(p) }
      valid_projects, projects_with_errors = results.partition { |r| r[:kind] == 'valid' }

      if projects_with_errors.empty?
        messages = [
          "#### **#{valid_projects.count}** projects without issues :white_check_mark:",
          'Everything should be good to merge!'
        ]
      else
        messages = ["#### **#{valid_projects.count}** projects without issues :white_check_mark:"]
        messages << projects_with_errors.map { |result| get_validation_message(result) }
      end
    else
      messages = projects.map { |p| review_project(p) }.map { |r| get_validation_message(r) }
    end

    markdown_body + messages.join("\n\n")
  end

  def self.get_header(initial_message)
    if initial_message
      GREETING_HEADER
    else
      UPDATE_HEADER
    end
  end

  def self.get_validation_message(result)
    path = result[:project].relative_path

    if result[:kind] == 'valid'
      "#### `#{path}` :white_check_mark:\nNo problems found, everything should be good to merge!"
    elsif result[:kind] == 'validation'
      message = result[:validation_errors].map { |e| "> - #{e}" }.join "\n"
      "#### `#{path}` :x:\nI had some troubles parsing the project file, or there were fields that are missing that I need.\n\nHere's the details:\n#{message}"
    elsif result[:kind] == 'tags'
      message = result[:tags_errors].map { |e| "> - #{e}" }.join "\n"
      "#### `#{path}` :x:\nI have some suggestions about the tags used in the project:\n\n#{message}"
    elsif result[:kind] == 'repository' || result[:kind] == 'label'
      "#### `#{path}` :x:\n#{result[:message]}"
    else
      "#### `#{path}` :question:\nI got a result of type '#{result[:kind]}' that I don't know how to handle. I need to mention @shiftkey here as he might be able to fix it."
    end
  end

  def self.review_project(project)
    validation_errors = SchemaValidator.validate(project)

    if validation_errors.any?
      return { project: project, kind: 'validation', validation_errors: validation_errors }
    end

    tags_errors = TagsValidator.validate(project)

    if tags_errors.any?
      return { project: project, kind: 'tags', tags_errors: tags_errors }
    end

    return { project: project, kind: 'valid' } unless project.github_project?

    repository_error = repository_check(project)

    unless repository_error.nil?
      return { project: project, kind: 'repository', message: repository_error }
    end

    label_error = label_check(project)

    unless label_error.nil?
      return { project: project, kind: 'label', message: label_error }
    end

    { project: project, kind: 'valid' }
  end

  def self.repository_check(project)
    # TODO: this looks for GITHUB_TOKEN underneath - it should not be hard-coded like this
    # TODO: cleanup the GITHUB_TOKEN setting once this is decoupled from the environment variable
    result = GitHubRepositoryActiveCheck.run(project)

    if result[:rate_limited]
      logger.info 'This script is currently rate-limited by the GitHub API'
      logger.info 'Marking as inconclusive to indicate that no further work will be done here'
      return nil
    end

    if result[:reason] == 'archived'
      return "The GitHub repository '#{project.github_owner_name_pair}' has been marked as archived, which suggests it is not active."
    end

    if result[:reason] == 'missing'
      return "The GitHub repository '#{project.github_owner_name_pair}' cannot be found. Please confirm the location of the project."
    end

    if result[:reason] == 'redirect'
      return "The GitHub repository '#{result[:old_location]}' is now at '#{result[:location]}'. Please update this project before this is merged."
    end

    if result[:reason] == 'error'
      return "The GitHub repository '#{project.github_owner_name_pair}' could not be confirmed. Error details: #{result[:error]}"
    end

    nil
  end

  def self.label_check(project)
    result = GitHubRepositoryLabelActiveCheck.run(project)

    if result[:rate_limited]
      logger.info 'This script is currently rate-limited by the GitHub API'
      logger.info 'Marking as inconclusive to indicate that no further work will be done here'
      return nil
    end

    if result[:reason] == 'repository-missing'
      return "I couldn't find the GitHub repository '#{project.github_owner_name_pair}' that was used in the `upforgrabs.link` value." \
            " Please confirm this is correct or hasn't been mis-typed."
    end

    yaml = project.read_yaml
    label = yaml['upforgrabs']['name']

    if result[:reason] == 'missing'
      return "The `upforgrabs.name` value '#{label}' isn't in use on the project in GitHub." \
            ' This might just be a mistake due because of copy-pasting the reference template or be mis-typed.' \
            " Please check the list of labels at https://github.com/#{project.github_owner_name_pair}/labels and update the project file to use the correct label."
    end

    link = yaml['upforgrabs']['link']
    url = result[:url]

    link_needs_rewriting = link != url && link.include?('/labels/')

    if link_needs_rewriting
      return "The label '#{label}' for GitHub repository '#{project.github_owner_name_pair}' does not match the specified `upforgrabs.link` value. Please update it to `#{url}`."
    end

    nil
  end

  private_class_method :review_project
  private_class_method :repository_check
  private_class_method :label_check
end
