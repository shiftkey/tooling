# frozen_string_literal: true

require_relative '../test_helper'

class CommandLineFormatterTests < Minitest::Test
  def test_command_line_lists_failing_files
    result = {
      projects: {
        '_data/projects/first.yml': {
          errors: []
        },
        '_data/projects/second.yml': {
          errors: [
            'No tags defined for file',
            "Field 'something' expects a URL but instead found 'foo'"
          ]
        }
      }
    }

    out, = capture_io do
      CommandLineFormatter.output(result)
    end

    assert_match %r{  - _data/projects/second.yml}, out
    assert_match(/    - No tags defined for file/, out)
    assert_match(/    - Field 'something' expects a URL but instead found 'foo'/, out)
  end

  def test_command_line_displays_success
    result = {
      projects: {
        '_data/projects/first.yml': {
          errors: []
        },
        '_data/projects/second.yml': {
          errors: []
        }
      }
    }

    out, = capture_io do
      CommandLineFormatter.output(result)
    end

    assert_match(/2 files processed - no errors found!/, out)
  end

  def test_command_line_lists_orphaned_project_files
    result = {
      project_files_at_root: [
        'first.yml',
        'second.yml'
      ]
    }

    out, = capture_io do
      CommandLineFormatter.output(result)
    end

    assert_match(/2 files found in root which look like project files/, out)
    assert_match(/  - first.yml/, out)
    assert_match(/  - second.yml/, out)
    assert_match %r{Move these inside _data/projects/ to ensure they are listed on the site}, out
  end

  def test_command_line_lists_invalid_data_files
    result = {
      invalid_data_files: [
        '_data/projects/first.json',
        '_data/projects/second.js',
        '_data/projects/third.txt',
        '_data/projects/fourth.xml'
      ]
    }

    out, = capture_io do
      CommandLineFormatter.output(result)
    end

    assert_match(/4 files found in projects directory which are not YAML files:/, out)
    assert_match %r{  - _data/projects/first.json}, out
    assert_match %r{  - _data/projects/second.js}, out
    assert_match %r{  - _data/projects/third.txt}, out
    assert_match %r{  - _data/projects/fourth.xml}, out
    assert_match(/Remove these from the repository as they will not be used by the site/, out)
  end
end
