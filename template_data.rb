
require_relative "template.rb"

## will eventually load template files from folder.  hard-coded first couple for quick testing
def load_template_data()
    templates = []
    templates << TemplateDefinition.new("int {0:string}", "{0} SDWORD 0", true)
    templates << TemplateDefinition.new("int {0:string} = {1:int}", "{0} SDWORD {1}", true)
    templates << TemplateDefinition.new("string {0:string} = {1:string}", "{0} db \"{1}\", $", true)
    templates << TemplateDefinition.new("print_int {0:string}", "mov ah, 9\nmov edx, {0}\nint 21h") # relies on DOS interrupts... not the best idea but it's short
    templates << TemplateDefinition.new("{0:string} = {1:int} + {2:int}", "add eax, {1}\nadd eax, {2}\nmov {0}, eax")
    templates << TemplateDefinition.new("{0:string} = {1:string} + {2:int}", "mov {r1:!eax:reg}, {1}\nadd {r1}, {2}\nmov {0}, eax")
    templates << TemplateDefinition.new("{0:string} = {1:int} + {2:string}", "mov {r1:!eax:reg}, {2}\nadd {r1}, {1}\n mov {0}, eax")
    return templates
end
