class TemplateDefinition

    require "logger"

    def initialize(pattern, translation)
        @logger = Logger.new STDOUT, "TemplateDefinition"

        @logger.unknown "test"

        @pattern = pattern
        @translation = translation

        @token_pattern = []

        # generate validation token stream
        pattern.split(" ").each do |token|
            if DynamicArgument.argument? token then
                @token_pattern << DynamicArgument.new(token)
            elsif Operator.operator? token then
                @token_pattern << Operator.new(token)
            else
                print("Unrecognized symbol in TemplateDefinition: \"#{token}\"\n")
            end
        end
    end

    def full_match?(token_list)
        print "\n"
        print(token_list)
        print "\n"
        if token_list.length != @token_pattern.length then
            print("Template for #{@pattern} was not satasified.\n")
            return false
        end
        i=0
        @token_pattern.each do |token|
            if token.is_a?(Operator) and !(Operator.operator? token_list[i] and Operator.new(token_list[i]).operator == token.operator) then
                print "NODICE:op\n"
                return false
            elsif token.is_a?(DynamicArgument) and !(token.valid_type? token_list[i]) then
                print "NODICE:arg\n"
                return false
            end
            i+=1
        end
        print "Template match found!\n"
        return true
    end

    def translate(token_list)
        "CODE"
    end
end

class DynamicArgument

    attr_reader :value
    attr_reader :name
    attr_reader :type_restriction
    attr_reader :target

    def initialize(string)
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
        print("Loaded DynamicArgument with #{@type_restriction}.\n")
    end

    def valid_type?(argument)
        if @type_restriction == nil then
            return true
        end

        is_int = Integer(argument) rescue nil

        if is_int != nil then
            if @type_restriction.include? "integer" or @type_restriction.include? "int" then
                return true
            end
        elsif @type_restriction.include? "string" or @type_restriction.include? "str" then
            print("Considering \"#{argument}\" as variable/string\n")
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

    attr_reader :operator

    def initialize(string)
        @operator = string
    end

    def self.operator?(string)
        print("Checking if #{string} is an operator.")
        if ["+","-","=","*","/"].include? string then
            print("... true\n")
            return true
        end
        print("... false\n")
        return false
    end
end
