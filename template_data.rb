
require_relative "template_types/simple_template.rb"

class TemplateStorage

  def initialize(compiler)
    @compiner = compiler
    @database = load_template_data()
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

      templates << SimpleTemplateDefinition.new(
        pattern: template["pattern"],
        data_translation: template["data_translation"] || "",
        code_translation: template["code_translation"] || "",
        externs: template["externs"] || "",
        bss_translation: template["bss_translation"] || ""
      )
    end

    return templates
  end

  ## will eventually load template files from folder.  hard-coded first couple for quick testing
  def load_template_data()
    templates = load_simple_templates()

    # non-functional
    # templates << SimpleTemplateDefinition.new(pattern: "string {0:string} = \"{1:string}\"", data_translation: "{0}: db \"{1}\", $")

    # non-functional
    # templates << SimpleTemplateDefinition.new(pattern: "print_string {0:string}", data_translation: "string_pattern db \"%s\", 10, 0", code_translation: "push rbp\nmov rdi, string_pattern\nmov rsi, {0}\nxor rax, rax\ncall printf\npop rbp")

    return templates
  end

  # will eventually use my awesome trie to minimize search times
  def find_match(context, string)
    @database.each do |template|
      if template.full_match? context, string then
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
