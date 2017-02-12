
require_relative "template.rb"

## will eventually load template files from folder.  hard-coded first couple for quick testing
def load_template_data()
    templates = []
    templates << TemplateDefinition.new("{0:string} = {1:int} + {2:int}", "add eax, {1}\nadd eax, {2}\nmov {0}, eax")
    templates << TemplateDefinition.new("{0:string} = {1:string} + {2:int}", "mov {r1:!eax:reg}, {1}\nadd {r1}, {2}\nmov {0}, eax")
    templates << TemplateDefinition.new("{0:string} = {1:int} + {2:string}", "mov {r1:!eax:reg}, {2}\nadd {r1}, {1}\n mov {0}, eax")
    return templates
end
