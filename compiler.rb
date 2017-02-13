

class Compiler

    def initialize(source_file)
        # load templates
        require_relative "template_data.rb"
        templates = load_template_data()

        # load source file
        src = File.read(source_file).tr("\r","")
        match_targets = src.split("\n")

        require_relative "tokenizer.rb"

        data = []
        code = []

        match_targets.each do |target|
            token_lines = Tokenizer.tokenize(target)
            token_lines.each do |line|
                tokens = line.split(" ")
                match = false
                templates.each do |template|
                    if template.full_match? tokens then
                        parts = template.translate(tokens)
                        data << parts[0] if !parts[0].nil?
                        code << parts[1] if !parts[1].nil?
                        match = true
                        break
                    end
                end
                if !match then
                    print "\n\nCould not match \"#{line}\" to any templates.  The syntax is probably invalid.\n"
                    return
                end
            end
        end


        File.open("output.asm", 'w') { |file|
            file.write ".stack\n"
            file.write "\n.model flat\n"
            file.write "\n.data\n"
            data.each do |d|
                file.write d.to_s + "\n"
            end

            file.write "\n.code\n"
            code.each do |c|
                file.write c.to_s + "\n"
            end
        }
    end

end

Compiler.new("test.conv")
