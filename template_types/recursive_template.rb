
# Contains a template in which some or all of the translations require recursive evaluation
class RecursiveTemplate

  require 'logger'
  require_relative "../utils.rb"
  require_relative "../dynamic_argument.rb"

  def initialize(yaml)
    @logger = Logger.new STDOUT, "RecursiveTemplate"
    @logger.level = Logger.const_get yaml["log_level"] || "WARN"

    @pattern = yaml["pattern"]
    @code_translation = yaml["code_translation"] || ""

    @token_pattern = []

    @translation_args = Hash.new

    @data_translation = yaml["data_translation"] || ""

    @bss_translation = yaml["bss_translation"] || ""

    @optimization_level = yaml["optimization_level"] || 0

    @externs = Utils.whitespace_split_ignore(yaml["externs"] || "")

    @names = yaml["names"].split("\n") || []

    @template_line_db = {}

    # generate validation token stream
    @pattern.split("\n").each do |line|
      Utils.whitespace_split_ignore(line).each do |token|
        if DynamicArgument.argument? token then
          @token_pattern << DynamicArgument.new(token)
          @translation_args[@token_pattern[-1].name] = @token_pattern[-1].value
        else
          # @logger.warn "Unrecognized symbol in RecursiveTemplate: \"#{token}\"\n"
          @token_pattern << token
        end
      end
    end
  end

  def full_match?(transaction, line, translate: false)
    @template_line_db = {}

    @logger.debug "Matching " + line.to_s

    finalizer = @pattern.split("\n")[-1]
    pattern_index = 0

    @logger.debug "Matching up to finalizer: #{finalizer}"
    loop do
      line_tokens = Utils.whitespace_split_ignore(line)

      if line.tr("\n", '').strip() == finalizer then
        return true
      end

      line_tokens.each do |source_token|
        token = @token_pattern[pattern_index]

        if token.is_a?(DynamicArgument) and token.name == "recurse" then
          # breakout into recursive template matching
          while line != finalizer do
            template = transaction.match_line(line: line)
            if template then
              # store which template matched which line for translation later
              @template_line_db[line] = template
              if transaction.has_next_line() then
                line = transaction.next_line()
              else
                # reached end of input stream with no finalizer for this recursive template
                return false
              end
            else
              # didn't find any matches for a line in the recursive block
              return false
            end
          end
          # there's nothing to translate for the finalizer so return true
          # and skip the finalizer line
          transaction.next_line()
          return true
        end

        if token.is_a?(DynamicArgument) and !(token.valid_type? transaction, source_token) then
          @logger.debug "NODICE:arg:\t #{token.type_restriction} =/= \"#{source_token.to_s}\"\n"
          return false
        elsif token.is_a?(DynamicArgument) and token.valid_type? transaction, source_token then
          @translation_args[token.name] = token.value
        elsif !(token.to_s.eql? source_token.to_s) then
          @logger.debug "NODICE:constant mismatch:\t \"#{token.to_s}\" =/= \"#{source_token.to_s}\"\n"
          return false
        end

        pattern_index+=1
      end

      return false if !transaction.has_next_line() # return false on missing finalizer
      line = transaction.next_line()
      break if line.to_s == finalizer.to_s
    end


    # we shouldn't get here so assume that this template doesn't match
    @logger.debug "RecursiveTemplate really should not be here"
    return false
  end

  def translate(transaction, line)
    # fill translation_args with the requested name generations if there are any
    @names.each do |name|
      generated_name = transaction.generate_label(name)
      @translation_args[name] = generated_name
    end

    # these templates only apply to the code segment right now...
    # TODO research if i need to bring this template to the other segments

    finalizer = @pattern.split("\n")[-1]

    result = ""
    in_arg = false
    arg_name = ""
    @code_translation.chars.each do |char|
      if char == "\n" then
        result << "\n"
        next
      end

      if in_arg and char == "}" then
        # finished parsing translation_arg name
        # so lookup what to replace it with
        if arg_name == "recurse" then
          transaction.add symbol: "code", text: result
          result = ""

          line = transaction.next_line()

          loop do
            break if line.nil? or line == finalizer
            puts "RECURSIVE #{line}"
            puts transaction.unpack :types
            template = transaction.match_line(line: line)
            puts transaction.unpack :types
            template.translate(transaction, line)
            puts transaction.unpack :types
            line = transaction.next_line()
          end
          arg_name = ""
          in_arg = false
        end

        case arg_name.chars.select { |c| c == ":" }.length
        when 0
          result << @translation_args[arg_name].to_s
        when 1
          result << @translation_args[arg_name[0]]
        when 2
          result << @translation_args[arg_name[0]]
        end

        # finished with this translation arg so reset and continue
        arg_name = ""
        in_arg = false
      elsif in_arg then
        arg_name << char
      elsif char == "{" and !in_arg then
        in_arg = true
      else
        result << char
      end
    end
    transaction.add symbol: "code", text: result
  end


  # mostly taken from SimpleTemplate
  # TODO refactor class hierarchy
  def translate_internal(transaction, line)
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

    return result
  end

end
