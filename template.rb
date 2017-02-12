class TemplateDefinition

    require "logger"

    def initialize(pattern, translation)
        @logger = Logger.new STDOUT, "TemplateDefinition"

        @pattern = pattern
        @translation = translation

        @token_pattern = []

        @translation_args = Hash.new

        # generate validation token stream
        pattern.split(" ").each do |token|
            if DynamicArgument.argument? token then
                @token_pattern << DynamicArgument.new(token)
                @translation_args[@token_pattern[-1].name] = @token_pattern[-1].value
            elsif Operator.operator? token then
                @token_pattern << Operator.new(token)
            else
                @logger.warn "Unrecognized symbol in TemplateDefinition: \"#{token}\"\n"
            end
        end
    end

    def full_match?(token_list)
        @logger.info "Matching agianst " + token_list.to_s
        if token_list.length != @token_pattern.length then
            @logger.info "Template for #{@pattern} was not satasified.\n"
            return false
        end
        i=0
        @token_pattern.each do |token|
            if token.is_a?(Operator) and !(Operator.operator? token_list[i] and Operator.new(token_list[i]).operator == token.operator) then
                @logger.debug "NODICE:op\n"
                return false
            end

            if token.is_a?(DynamicArgument) and !(token.valid_type? token_list[i]) then
                @logger.debug "NODICE:arg\n"
                return false
            elsif token.is_a?(DynamicArgument) and token.valid_type? token_list[i] then
                @translation_args[token.name] = token.value
            end
            i+=1
        end
        @logger.info "Template match found!\n"
        return true
    end

    def translate(token_list)

        vars = Hash.new

        # scan for list of replacement key names
        @translation.split(" ").each do |token|
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
                    type = token[1] # reg or mem :: will matter when i actually do the dynamic register resolution and memory resolution
                when 2
                    name = token[0]
                    needs_resolve << token
                end

                if !@translation_args.include? name then
                    @translation_args[name] = nil
                end
            end
        end

        # we have all the variables required for translation so lets populate the hashtable with generated placeholders
        # TODO(bk5115545)

        # hashtable has everything we need to fufill this translation
        # so translate
        result = ""
        in_arg = false
        current_parse = ""

        @translation.chars.each do |char|
            if char == "\n" then
                result << "\n"
                next
            end
            if in_arg and char == "}" then
                case current_parse.chars.select { |c| c == ":" }.length
                when 0
                    print "\n" + current_parse + "\n"
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

        return vars, result
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

class Operator
    # require "logger"

    attr_reader :operator

    def initialize(string)
        # @logger = Logger.new STDOUT, "Operator"
        @operator = string
    end

    def self.operator?(string)
        print "Checking if #{string} is an operator."
        if ["+","-","=","*","/"].include? string then
            print "... true\n"
            return true
        end
        print "... false\n"
        return false
    end
end
