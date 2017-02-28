
require_relative "template.rb"

class TemplateStorage

    def initialize(opts: {})
        @database = load_template_data()
    end

    ## will eventually load template files from folder.  hard-coded first couple for quick testing
    def load_template_data()
        templates = []
        templates << SimpleTemplateDefinition.new(pattern: "int {0:string}", data_translation: "{0}: DB 0")
        templates << SimpleTemplateDefinition.new(pattern: "int {0:string} = {1:int}", data_translation: "{0}: DB {1}")
        templates << SimpleTemplateDefinition.new(pattern: "string {0:string} = \"{1:string}\"", data_translation: "{0}: db \"{1}\", $")
        templates << SimpleTemplateDefinition.new(pattern: "{0:string} = {1:int}", code_translation: "mov [rel {0}], {1}")

        templates << SimpleTemplateDefinition.new(pattern: "print_string {0:string}", data_translation: "string_pattern db \"%s\", 10, 0", code_translation: "push rbp\nmov rdi, string_pattern\nmov rsi, {0}\nxor rax, rax\ncall printf\npop rbp")
        templates << SimpleTemplateDefinition.new(pattern: "print_int {0:string}", data_translation: "int_pattern db \"%x\", 10, 0", code_translation: "sub rsp, 8\nmov rsi, {0}\nmov rdi, int_pattern\nxor rax, rax\ncall printf")

        templates << SimpleTemplateDefinition.new(pattern: "{0:string} = {1:int} + {2:int}", code_translation: "; add {1} and {2}\n; store into {0}\nmov eax, {1}\nadd eax, {2}\nmov [rel {0}], eax")
        templates << SimpleTemplateDefinition.new(pattern: "{0:string} = {1:string} + {2:int}", code_translation: "mov eax, [rel {1}]\nadd eax, {2}\nmov [rel {0}], eax")
        templates << SimpleTemplateDefinition.new(pattern: "{0:string} = {1:int} + {2:string}", code_translation: "mov eax, 0\nmov {r1:!eax:reg}, [rel {2}]\nadd {r1}, {1}\n mov [rel {0}], eax")
        return templates
    end

    # will eventually use my awesome trie to minimize search times
    def find_match(string)
        @database.each do |template|
            if template.full_match? string then
                return template
            end
        end
        return false
    end

    # might do something more complex here
    def translate(compiler, template, string)
        return template.translate(compiler, string)
    end

end
