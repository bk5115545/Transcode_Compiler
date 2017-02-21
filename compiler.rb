

class Compiler

    @@history = {}
    attr_reader :history

    def initialize(source_file)

        @code = []
        @data = []
        @transactions = []
        @warnings = []
        @errors = []

        @token_source = []
        @token_index = 0

        # load templates
        require_relative "template_data.rb"
        templates = load_template_data()

        # load source file
        src = File.read(source_file).tr("\r","")
        @token_source = src.split("\n")

        require_relative "tokenizer.rb"

        @token_source.each do |target|
            token_lines = Tokenizer.tokenize(target)
            token_lines.each do |line|
                tokens = line.split(" ")
                match = false
                templates.each do |template|
                    if template.full_match? tokens then
                        parts = template.translate(tokens)
                        @data << parts[0] if !parts[0].nil?
                        @code << parts[1] if !parts[1].nil?
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


        finalize("output.asm")
    end

    def add_code(code)
        @code << code
    end

    def add_data(symbol, code)
        if @data[symbol].nil? then
            @data[symbol] = code
        else
            # TODO
            self.warning("WARNING: ")
        end
    end


    def has_next_line()
        return @token_index - 1 < @token_source.length()
    end

    def next_line()
        @token_index += 1
        return @token_source[@token_index]
    end

    def transaction_begin()
        @transactions << [@token_index.dup, @code.dup, @data.dup, @warnings.dup, @errors.dup]
    end

    def in_transaction()
        return @transactions.length() > 0
    end

    def transaction_commit()
        # TODO
    end

    def transaction_rollback()
        @token_index, @code, @data, @warnings, @errors = @transactions[@transactions.length()-1]
    end

    def throw_warning(string)
        # TODO
    end

    def throw_error(string, terminate=true)
        # TODO
    end

    def finalize(filename)
        File.open(filename, 'w') { |file|
            file.write ".stack\n"
            file.write "\n.model flat\n"
            file.write "\n.data\n"
            @data.each do |d|
                file.write d.to_s + "\n"
            end

            file.write "\n.code\n"
            @code.each do |c|
                file.write c.to_s + "\n"
            end
        }
    end


end

Compiler.new("test.conv")
