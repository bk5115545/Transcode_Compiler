
require_relative "template_types/simple_template.rb"
require_relative "template_types/recursive_template.rb"

class TemplateStorage

  def initialize(compiler)
    @compiner = compiler
    @database = load_template_data()
  end

  def self.instance()
    if @database.nil? then
      print "\n\nERROR: Loaded instance of TemplateStorage when none was initialized.\n"
      return nil
    else
      return self
    end
  end

  def load_simple_templates(foldername: "templates/simple_templates")
    templates = []
    require 'yaml'

    yaml_files = Dir.glob(File.join(foldername, "*.yaml"))
    yaml_files.each do |filename|
      template = YAML.load_file(filename)
      if template.nil? then
        @compiler.throw_warning "Error parsing template at #{filename}. It will be skipped."
        next
      end

      if template["template_type"].nil? then
        @compiler.throw_warning "Template with pattern \"#{template["pattern"]}\" did not declare a template_type.  Assuming \"simple\" based on location."
      elsif template["template_type"] != "simple" then
        @compiler.throw_warning "Template with pattern \"#{template["pattern"]}\" and type \"#{template["template_type"]}\" is being considered as template_type=simple based on location."
      end

      templates << SimpleTemplate.new(template)
    end

    return templates
  end

  def load_recursive_templates(foldername: "templates/recursive_templates")
    templates = []
    require 'yaml'

    yaml_files = Dir.glob(File.join(foldername, "*.yaml"))
    yaml_files.each do |filename|
      template = YAML.load_file(filename)
      if template.nil? then
        @compiler.throw_warning "Error parsing template at #{filename}. It will be skipped."
        next
      end

      if template["template_type"].nil? then
        @compiler.throw_warning "Template with pattern \"#{template["pattern"]}\" did not declare a template_type.  Assuming \"recursive\" based on location."
      elsif template["template_type"] != "recursive" then
        @compiler.throw_warning "Template with pattern \"#{template["pattern"]}\" and type \"#{template["template_type"]}\" is being considered as template_type=recursive based on location."
      end

      templates << RecursiveTemplate.new(template)
    end

    return templates
  end

  ## will eventually construct trie for efficient matching
  def load_template_data()
    templates = load_simple_templates()
    templates.push(*load_recursive_templates())

    return templates
  end

  # will eventually use my awesome trie to minimize search times
  def find_match(transaction: nil, line: "")
    @database.each do |template|
      if template.full_match? transaction, line then
        return template
      end
    end
    return false
  end

  # might do something more complex here
  def translate(transaction, template, string)
    return template.translate(transaction, string)
  end

end
