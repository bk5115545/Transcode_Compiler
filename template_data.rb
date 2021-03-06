
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

    # load the supported CPU features
    features = `cat /proc/cpuinfo | grep "flags" | head -1`.split(":")[1].split(/\s/)

    # prune templates that don't have all of their required features satasified
    # (required & available).size will == available.size if and only if all the required features already exist in the available features set
    # this is a set intersection implemented using arrays
    templates.reject! { |t| (t.list_required_features() | features).size != features.size}


    return templates
  end

  # will eventually use my awesome trie to minimize search times
  def find_match(transaction: nil, line: "")
    matches = []
    @database.each do |template|
      if template.full_match? transaction, line then
        matches << template
      end
    end
    return matches
  end

  # might do something more complex here
  def translate(transaction, template, string)
    return template.translate(transaction, string)
  end

end
