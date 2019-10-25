require 'minitest/autorun'
require './lib/up_for_grabs_tooling'

class ProjectValidatorTests < Minitest::Test
  def test_valid_file_returns_no_errors
    schemer = get_schemer
    project = get_project("valid_project_file.yml")

    result = ProjectValidator.validate(project, schemer)

    assert result.empty?
  end

  def test_upper_case_tag_error
    schemer = get_schemer
    project = get_project("error_upper_case_tag.yml")

    result = ProjectValidator.validate(project, schemer)

    assert_equal result[0], "Tag 'Web' contains invalid characters. Allowed characters: a-z, 0-9, +, #, . or -"
  end

  def get_schemer
    root = File.dirname(__dir__)
    schema = Pathname.new("#{root}/schema.json")
    JSONSchemer.schema(schema)
  end

  def get_project(name)
    full_path =  Pathname.new("#{__dir__}/fixtures/projects/#{name}")
    Project.new(name, full_path.to_s)
  end
end
