
require_relative "template.rb"

class TemplateStorage

    def initialize(opts: {})
        @database = load_template_data()
    end

    ## will eventually load template files from folder.  hard-coded first couple for quick testing
    def load_template_data()
        templates = []
        templates << TemplateDefinition.new("int {0:string}", "", "{0} SDWORD 0")
        templates << TemplateDefinition.new("int {0:string} = {1:int}", "", "{0} SDWORD {1}")
        templates << TemplateDefinition.new("string {0:string} = \"{1:string}\"", "", "{0} db \"{1}\", $")
        templates << TemplateDefinition.new("{0:string} = {1:int}", "mov {0}, {1}")
        templates << TemplateDefinition.new("print_int {0:string}", "; print {0}\nmov ah, 9\nmov edx, {0}\nint 21h\n") # relies on DOS interrupts... not the best idea but it's short
        templates << TemplateDefinition.new("{0:string} = {1:int} + {2:int}", "; add {1} and {2}\n; store into {0}\nmov eax, {1}\nadd eax, {2}\nmov {0}, eax\n")
        templates << TemplateDefinition.new("{0:string} = {1:string} + {2:int}", "mov eax, {1}\nadd eax, {2}\nmov {0}, eax\n")
        templates << TemplateDefinition.new("{0:string} = {1:int} + {2:string}", "mov eax, 0\nmov {r1:!eax:reg}, {2}\nadd {r1}, {1}\n mov {0}, eax\n")
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
