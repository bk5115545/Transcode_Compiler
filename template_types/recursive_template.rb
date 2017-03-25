
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

    @@recursive_nest_level_translate = 0

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

    start_index = transaction.get_index()

    @logger.debug "Matching " + line.to_s

    finalizer = @pattern.split("\n")[-1]
    pattern_index = 0

    @logger.debug "Matching up to finalizer: #{finalizer}"
    loop do
      line_tokens = Utils.whitespace_split_ignore(line)

      line_tokens.each do |source_token|
        token = @token_pattern[pattern_index]

        if token.is_a?(DynamicArgument) and token.name == "recurse" then
          # breakout into recursive template matching
          line = Utils.whitespace_split_ignore(line).join(" ") # try at whitespace neutrality (indention)

          @logger.debug "ENTERING WHILE"
          while true do
            @logger.debug "testing: #{line} == #{finalizer}"
            if line == finalizer then
              @logger.debug "Found finalizer:#{transaction.get_index()}: #{finalizer}"
              # there's nothing to translate for the finalizer so return true
              # and skip the finalizer line
              line = Utils.whitespace_split_ignore(line).join(" ") # try at whitespace neutrality (indention)
              @logger.debug "SKIPPING #{line}"
              @logger.debug "Found finalizer for recursion."
              # didn't find any matches for a line in the recursive block
              return true
            end

            template = transaction.match_line(line: line)
            if template then
              # store which template matched which line for translation later
              @template_line_db[line] = template
              if transaction.has_next_line() then
                line = transaction.next_line()
                line = Utils.whitespace_split_ignore(line).join(" ") # try at whitespace neutrality
                @logger.debug "STARTING RECURSIVE MATCH: #{line}" if line != finalizer
              else
                # reached end of input stream with no finalizer for this recursive template
                @logger.debug "End of input stream with no matching finalizer."
                return false
              end
            else
              # no template and line isn't the finalizer
              return false
            end
          end
          # end of the recursion block without returning true so counting this as false
          # TODO this is where an "else" keyword would be implemented with another recursive block
          # something like if line == "else"
          return false
        end

        if token.is_a?(DynamicArgument) and !(token.valid_type? transaction, source_token) then
          @logger.debug "NODICE:arg:\t #{token.type_restriction} =/= \"#{source_token.to_s}\"\n"
          return false
        elsif token.is_a?(DynamicArgument) and token.valid_type? transaction, source_token then
          @translation_args[token.name + start_index.to_s] = token.value
        elsif !(token.to_s.eql? source_token.to_s) then
          @logger.debug "NODICE:constant mismatch:\t \"#{token.to_s}\" =/= \"#{source_token.to_s}\"\n"
          return false
        end

        pattern_index+=1
      end

      @logger.debug "BROKE OUT ON LINE: #{line}"

      return false if !transaction.has_next_line() # return false on missing finalizer
      line = transaction.next_line()
      line = Utils.whitespace_split_ignore(line).join(" ") # try at whitespace neutrality
    end


    # we shouldn't get here so assume that this template doesn't match
    @logger.warn "RecursiveTemplate really should not be here"
    return false
  end

  def translate(transaction, line)
    # fill translation_args with the requested name generations if there are any
    start_index = transaction.get_index()
    @names.each do |name|
      generated_name = transaction.generate_label(name)
      @translation_args[name + start_index.to_s] = generated_name
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
        puts "translating arg name: #{arg_name}"
        # finished parsing translation_arg name
        # so lookup what to replace it with
        if arg_name == "recurse" then
          puts "ENTERING RECURSE"
          # go ahead and add the current code to the transaction so the nested args are on top of the {recurse}
          # this only matters if {recurse} is before the finalizer (for the love of god it better be)
          transaction.add symbol: "code", text: result
          result = "" # already added this code so reset

          loop do
            line = Utils.whitespace_split_ignore(transaction.next_line()).join(" ")

            puts "CHECKING: #{line} == #{finalizer} "
            if line == finalizer then
              puts "SKIPPING: #{line}"
              in_arg = false
              arg_name = ""
              break
            end
            puts "STARTING RECURSIVE MATCH: #{line}"
            # save and restore the index so we don't step over lines by having to find a template again
            index = transaction.get_index()
            template = transaction.match_line(line: line)
            transaction.set_index index: index
            puts "STARTING RECURSIVE TRANSLATE: #{line}"
            template.translate(transaction, line)
          end
          next
        end

        case arg_name.chars.select { |c| c == ":" }.length
        when 0
          result << @translation_args[arg_name + start_index.to_s].to_s
        when 1
          result << @translation_args[arg_name[0] + start_index.to_s]
        when 2
          result << @translation_args[arg_name[0] + start_index.to_s]
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
    puts "recursion done"
    transaction.add symbol: "code", text: result
  end
end
