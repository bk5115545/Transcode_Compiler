class SimpleTemplateDefinition

  require "logger"

  attr_reader :translation, :pattern

  def initialize(pattern: "", code_translation: "", data_translation: "", externs: "", optimization_level: 0)
    @logger = Logger.new STDOUT, "SimpleTemplateDefinition"
    @logger.level = Logger::DEBUG

    @pattern = pattern
    @code_translation = code_translation

    @token_pattern = []

    @translation_args = Hash.new

    @data_translation = data_translation

    @optimization_level = optimization_level

    @externs = externs.split(/\W+/)

    # generate validation token stream
    pattern.split(" ").each do |token|
      if DynamicArgument.argument? token then
        @token_pattern << DynamicArgument.new(token)
        @translation_args[@token_pattern[-1].name] = @token_pattern[-1].value
      else
        # @logger.warn "Unrecognized symbol in SimpleTemplateDefinition: \"#{token}\"\n"
        @token_pattern << token
      end
    end
  end

  def full_match?(transaction, string)
    token_list = string.split(" ")
    @logger.info "Matching agianst " + token_list.to_s
    @logger.info "With pattern #{@pattern}"
    if token_list.length != @token_pattern.length then
      @logger.info "Template for was not satasified.\n"
      return false
    end
    i=0
    @token_pattern.each do |token|
      if token.is_a?(DynamicArgument) and !(token.valid_type? transaction, token_list[i]) then
        @logger.debug "NODICE:arg\n"
        return false
      elsif token.is_a?(DynamicArgument) and token.valid_type? transaction, token_list[i] then
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

  def translate(transaction, string)

    @externs.each { |extern| transaction.add symbol: "externs", text: extern}

    # translate data segment additions first so that we can validate that a name exists in the binary
    translate_data(transaction, string)

    # all variables referneced in the token stream are going to be defined in the binary now

    @code_translation.split(" ").each do |token|
      token = token.tr(",","")

      if DynamicArgument.argument? token then
        # make sure we have names allocated for these translation arguments
        # this is mostly only revelent for generated temporary memory locations or temp registers
        name = token[1..-2] # remove {}

        if @translation_args[name].to_i.nil? && !compiler.has_data(@translation_args[name]) then
          transaction.throw_warning("Trying to use \"#{@translation_args[name]}\" before it is defined.  This is not necessarily a problem.")
        end
      end
    end

    # hashtable has everything we need to fufill this translation
    translate_code(transaction, string)

    transaction.commit()
  end

  def translate_data(transaction, string)
    @data_translation.split("\n").each do |line|
      result = ""
      in_arg = false
      current_parse = ""

      symbol = line.split(" ")[0].tr("{","").tr("}","") # always the first word
      symbol = symbol.tr(":","")
      symbol = @translation_args[symbol]

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

      transaction.add symbol: "data", text: {symbol.to_s => [@token_pattern[0], result]}
    end
  end

  def translate_code(transaction, string)
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
      transaction.add symbol: "code", text: result
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

      when 2
        parts = string.split(":")
        @name = parts[0]
        @type_restriction = parts[1].split("|")
        @target = parts[2].split("|")
    end
    @logger.debug "Loaded DynamicArgument with #{@type_restriction}.\n"
  end

  def valid_type?(transaction, argument)
    if @type_restriction == nil then
      return true
    end

    is_int = Integer(argument) rescue nil
    is_float = Float(argument) rescue nil

    if is_int != nil || is_float != nil then
      if !is_int.nil? and @type_restriction.include? "integer" or @type_restriction.include? "int" then
          @value = argument.to_i
          return true
        elsif !is_float.nil? and @type_restriction.include? "float" then
          @value = argument.to_f
          return true
      end
    elsif @type_restriction.include? "string" or @type_restriction.include? "str" then
      # no type to lookup
      if @target.nil? then
        @logger.debug "Considering \"#{argument}\" as variable/string\n"
        @value = argument
        return true
        # need to make sure this variable name points to the correct type in memory
      elsif (@target.include? "int" or @target.include? "integer") and transaction.type_resolve(argument) == :int then
        @value = argument
        return true
      elsif @target.include? "float" and transaction.type_resolve(argument) == :float then
        @value = argument
        return true
      end
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
