

class Compiler

    def initialize(source_file)
        # load templates
        require_relative "template_data.rb"
        templates = load_template_data()

        # load source file
        src = File.read(source_file).tr("\r","")
        match_targets = src.split("\n")

        require_relative "tokenizer.rb"

        output = []
        match_targets.each do |target|
            token_lines = Tokenizer.tokenize(target)
            token_lines.each do |line|
                tokens = line.split(" ")
                match = false
                templates.each do |template|
                    if template.full_match? tokens then
                        output << template.translate(tokens)
                        match = true
                    end
                    break if match
                end
                if !match then
                    print "\n\nCould not match \"#{line}\" to any templates.  The syntax is probably invalid.\n"
                    return
                end
            end
        end
        File.open("output.asm", 'w') { |file|
            output.each do |out|
                data = out[0]
                line = out[1]
                
                file.write line
            end
        }
    end

end

Compiler.new("test.conv")
