class SimpleTemplate

  require "logger"
  require_relative "../utils.rb"
  require_relative "../dynamic_argument.rb"

  def initialize(yaml)
    @logger = Logger.new STDOUT, "SimpleTemplate"
    @logger.level = Logger.const_get yaml["log_level"] || "WARN"
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{severity} -- : #{msg}\n"
    end

    @pattern = yaml["pattern"]
    @code_translation = yaml["code_translation"] || ""

    @token_pattern = []

    @translation_args = Hash.new

    @data_translation = yaml["data_translation"] || ""

    @bss_translation = yaml["bss_translation"] || ""

    @optimization_level = yaml["optimization_level"] || "0"
    @optimization_level = @optimization_level.to_i

    @externs = Utils.whitespace_split_ignore(yaml["externs"] || "")

    @names = yaml["names"]|| ""
    @names = @names.split "\n"


    @require_features = yaml["require_features"] || ""
    @require_features.downcase!
    @require_features = Utils.whitespace_split_ignore(@require_features)

    # generate validation token stream
    Utils.whitespace_split_ignore(@pattern).each do |token|
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
    # split on \b excluding . and ,

    token_list = Utils.whitespace_split_ignore(string)

    @logger.debug "Matching agianst " + token_list.to_s
    @logger.debug "With pattern #{@pattern}".tr("\n","")

    if token_list.length != @token_pattern.length then
      @logger.debug "Template for was not satasified.\n"
      return false
    end
    i=0
    @token_pattern.each do |token|
      if token.is_a?(DynamicArgument) and !(token.valid_type? transaction, token_list[i]) then
        @logger.debug "NODICE:arg:\t #{token.type_restriction} =/= \"#{token_list[i].to_s}\"\n"
        return false
      elsif token.is_a?(DynamicArgument) and token.valid_type? transaction, token_list[i] then
        @translation_args[token.name] = token.value
      elsif !(token.to_s.eql? token_list[i].to_s) then
        @logger.debug "NODICE:constant mismatch:\t \"#{token.to_s}\" =/= \"#{token_list[i].to_s}\"\n"
        return false
      end
        i+=1
    end

    @logger.info "Template match found for \"#{string}\""
    return true
  end

  def translate(transaction, string)

    @externs.each { |extern| transaction.add symbol: "externs", text: extern}

    # fill translation_args with the requested name generations if there are any
    start_index = transaction.get_index()
    @names.each do |name|
      generated_name = transaction.generate_label(name)
      @translation_args[name + start_index.to_s] = generated_name
    end

    # translate data segment additions first so that we can validate that a name exists in the binary
    translate_data(transaction, string, start_index)

    # translate bss segment additions before code is translated so we can validate a name exists in the binary
    translate_bss(transaction, string, start_index)

    # all variables referneced in the token stream are going to be defined in the binary now

    Utils.whitespace_split_ignore(@code_translation).each do |token|
      # token = token.tr(",","") # don't think I need this anymore

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
    translate_code(transaction, string, start_index)

    transaction.commit()
    return true
  end

  def translate_internal(transaction, line, start_transaction_index)
    result = ""
    in_arg = false
    current_parse = ""

    symbol = line.split(" ")[0]
    start_index = symbol.index("{")
    finish_index = symbol.index("}")

    if !(start_index.nil? and finish_index.nil?) then
      symbol = symbol[start_index+1..finish_index-1]
      symbol = @translation_args[symbol]
    end

    line.chars.each do |char|
      if char == "\n" then
        result << "\n"
        next
      end
      if in_arg and char == "}" then
        case current_parse.chars.select { |c| c == ":" }.length
        when 0
          current_parse += start_transaction_index.to_s if @names.include? current_parse
          result << @translation_args[current_parse].to_s
        when 1
          current_parse += start_transaction_index.to_s if @names.include? current_parse
          result << @translation_args[current_parse[0]].to_s
        when 2
          current_parse += start_transaction_index.to_s if @names.include? current_parse
          result << @translation_args[current_parse[0]].to_s
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

    return symbol, result
  end

  def translate_data(transaction, string, start_index)
    @data_translation.split("\n").each do |line|
      next if line.length == 0
      symbol, result = translate_internal(transaction, line, start_index)
      transaction.add symbol: "data", text: {symbol.to_s => [@token_pattern[0], result]}
    end
  end

  def translate_bss(transaction, string, start_index)
    @bss_translation.split("\n").each do |line|
      next if line.length == 0
      symbol, result = translate_internal(transaction, line, start_index)
      transaction.add_bss text: {symbol.to_s => [@token_pattern[0], result]}
    end
  end

  def translate_code(transaction, string, start_index)
    @code_translation.split("\n").each do |line|
      next if line.length == 0
      result = translate_internal(transaction, line, start_index)[1]
      transaction.add symbol: "code", text: result
    end
  end

  def get_optimization_level()
    return @optimization_level
  end

  def list_required_features()
    return @require_features
  end
end
