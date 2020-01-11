# frozen_string_literal: true

class CommandLineValidator
  def self.validate(root, schemer = nil)
    projects = Dir["#{root}/_data/projects/*.yml"].map do |f|
      relative_path = Pathname.new(f).relative_path_from(root).to_s
      Project.new(relative_path, f)
    end

    if schemer.nil?
      library_root = File.dirname(File.dirname(__dir__))
      schema = Pathname.new("#{library_root}/schema.json")
      schemer = JSONSchemer.schema(schema)
    end

    results = {}

    projects.each do |p|
      errors = SchemaValidator.validate(p, schemer)
      errors = errors.concat TagsValidator.validate(p)

      results.store(p.relative_path, errors: errors)
    end

    second = DirectoryValidator.validate(root)

    { projects: results }.merge(second)
  end
end
