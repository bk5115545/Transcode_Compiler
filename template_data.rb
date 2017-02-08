
require_relative "template.rb"

## will eventually load template files from folder.  hard-coded first couple for quick testing
def load_template_data()
    templates = []
    templates << TemplateDefinition.new("{0:string} = {1:int} + {2:int}", "add {1}, {2}\nmov {0}, eax")
    templates << TemplateDefinition.new("{0:string} = {1:string} + {2:int}", "mov {reg:!eax:r1}, {1}\nadd {r1}, {2}\nmov {0}, eax")
    templates << TemplateDefinition.new("{0:string} = {1:int} + {2:string}", "mov {reg:!eax:r1}, {2}\nadd {r1}, {1}\n mov {0}, eax")
    return templates
end
