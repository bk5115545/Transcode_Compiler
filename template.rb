class TemplateDefinition

    require "logger"

    attr_reader :translation, :pattern

    def initialize(pattern, code_translation, data_translation="")
        @logger = Logger.new STDOUT, "TemplateDefinition"
        @logger.level = Logger::DEBUG

        @pattern = pattern
        @code_translation = code_translation

        @token_pattern = []

        @translation_args = Hash.new

        @data_translation = data_translation

        # generate validation token stream
        pattern.split(" ").each do |token|
            if DynamicArgument.argument? token then
                @token_pattern << DynamicArgument.new(token)
                @translation_args[@token_pattern[-1].name] = @token_pattern[-1].value
            else
                @logger.warn "Unrecognized symbol in TemplateDefinition: \"#{token}\"\n"
                @token_pattern << token
            end
        end
    end

    def full_match?(string)
        token_list = string.split(" ")
        @logger.info "Matching agianst " + token_list.to_s
        if token_list.length != @token_pattern.length then
            @logger.info "Template for #{@pattern} was not satasified.\n"
            return false
        end
        i=0
        @token_pattern.each do |token|
            if token.is_a?(DynamicArgument) and !(token.valid_type? token_list[i]) then
                @logger.debug "NODICE:arg\n"
                return false
            elsif token.is_a?(DynamicArgument) and token.valid_type? token_list[i] then
                @translation_args[token.name] = token.value
            elsif !(token.to_s.eql? token_list[i].to_s) then
                @logger.debug "NODICE:constant mismatch\n"
                return false
            end
            i+=1
        end
        @logger.info "Template match found!\n"
        return true
    end

    def translate(compiler, string)
        compiler.transaction_begin()

        # translate data segment additions first so that we can validate that a name exists in the binary
        translate_data(compiler, string)

        # all variables referneced in the token stream are going to be defined in the binary now

        @code_translation.split(" ").each do |token|
            token = token.tr(",","")

            if DynamicArgument.argument? token then
                # make sure we have names allocated for these translation arguments
                # this is mostly only revelent for generated temporary memory locations or temp registers
                token = token[1..-2] # remove {}
                name = nil
                case token.chars.select { |c| c == ":" }.length
                when 0
                    name = token
                when 1
                    name = token[0]
                    type = token[1] # reg or mem :: will matter when i actually do the dynamic register resolution and memory allocation
                when 2
                    name = token[0]
                    needs_resolve << token
                end

                if @translation_args[name].to_i.nil? && !compiler.has_data(@translation_args[name]) then
                    compiler.throw_warning("Trying to use \"#{@translation_args[name]}\" before it is defined.  This is not necessarily a problem.")
                end
            end
        end

        # hashtable has everything we need to fufill this translation
        translate_code(compiler, string)

        compiler.transaction_commit(0)
    end

    def translate_data(compiler, string)
        @data_translation.split("\n").each do |line|
            result = ""
            in_arg = false
            current_parse = ""

            dynamic_defined = line.split(" ")[0].tr("{","").tr("}","") # always the first word
            symbol = @translation_args[dynamic_defined].to_s

            line.chars.each do |char|
                if char == "\n" then
                    result << "\n"
                    next
                end
                if in_arg and char == "}" then
                    case current_parse.chars.select { |c| c == ":" }.length
                    when 0
                        result << @translation_args[current_parse].to_s
                    when 1
                        result << @translation_args[current_parse[0]]
                    when 2
                        result << @translation_args[current_parse[0]]
                    end
                    current_parse = ""
                    in_arg = false
                elsif in_arg then
                    current_parse << char
                elsif char == "{" and !in_arg then
                    in_arg = true
                else
                    result << char
                end
            end

            compiler.add_data(symbol, result)
        end
    end

    def translate_code(compiler, string)
        @code_translation.split("\n").each do |line|
            result = ""
            in_arg = false
            current_parse = ""


            line.chars.each do |char|
                if char == "\n" then
                    result << "\n"
                    next
                end
                if in_arg and char == "}" then
                    case current_parse.chars.select { |c| c == ":" }.length
                    when 0
                        result << @translation_args[current_parse].to_s
                    when 1
                        result << @translation_args[current_parse[0]]
                    when 2
                        result << @translation_args[current_parse[0]]
                    end
                    current_parse = ""
                    in_arg = false
                elsif in_arg then
                    current_parse << char
                elsif char == "{" and !in_arg then
                    in_arg = true
                else
                    result << char
                end
            end
            compiler.add_code result
        end
    end
end



class DynamicArgument

    require "logger"

    attr_reader :value
    attr_reader :name
    attr_reader :type_restriction
    attr_reader :target

    def initialize(string)
        @logger = Logger.new STDOUT, "DynamicArgument"
        @logger.level = Logger::WARN

        @name = nil
        @type_restriction = nil
        @value = nil
        @target = nil

        string = string[1..-2]

        # parse type restriction and name if they exist
        case string.chars.select { |c| c == ":" }.length
            when 0
                @name = string

            when 1
                parts = string.split(":")
                @name = parts[0]
                @type_restriction = parts[1].split("|")
                #print("#{@type_restriction}\n")

            when 2
                parts = string.split(":")
                @name = parts[0]
                @type_restriction = parts[1].split("|")
                @target = parts[3].split("|")
        end
        @logger.debug "Loaded DynamicArgument with #{@type_restriction}.\n"
    end

    def valid_type?(argument)
        if @type_restriction == nil then
            return true
        end

        is_int = Integer(argument) rescue nil

        if is_int != nil then
            if @type_restriction.include? "integer" or @type_restriction.include? "int" then
                @value = argument.to_i
                return true
            end
        elsif @type_restriction.include? "string" or @type_restriction.include? "str" then
            @logger.info "Considering \"#{argument}\" as variable/string\n"
            @value = argument
            return true
        end

        return false
    end

    def self.argument?(string)
        if string[0] == "{" && string[-1] == "}" && string[1..-2] != nil then
            return true
        end
        return false
    end
end
