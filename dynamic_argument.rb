class DynamicArgument

  require "logger"

  @@logger = nil

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

      when 2
        parts = string.split(":")
        @name = parts[0]
        @type_restriction = parts[1].split("|")
        @target = parts[2].split("|")
    end
    self.class.logging().debug "Loaded DynamicArgument with #{@type_restriction}.\n"
  end

  def self.logging()
    if @@logger.nil? then
      @@logger = Logger.new STDOUT, "DynamicArgument" if @@logger.nil?
      @@logger.level = Logger::INFO
    end
    return @@logger
  end

  def valid_type?(transaction, argument)
    if @type_restriction == nil then
      return true
    end

    # puts "#{argument}\t#{transaction.type_resolve(argument).to_s}"

    is_int = Integer(argument) rescue nil
    is_float = Float(argument) rescue nil
    is_bool = Bool(argument) rescue nil

    self.class.logging().debug "#{argument} is_int: #{is_int} is_float: #{is_float} is_bool: #{is_bool}"

    if is_int != nil || is_float != nil then
      if !is_int.nil? and (@type_restriction.include? "integer" or @type_restriction.include? "int") then
        @value = argument.to_i
        return true
      elsif !is_float.nil? and @type_restriction.include? "float" then
        @value = argument.to_f
        return true
      elsif !is_int.nil? and (@type_restriction.include? "bool" or @type_restriction.include? "boolean") then
        @value = argument.to_i
        return true
      end
    elsif @type_restriction.include? "string" or @type_restriction.include? "str" then
      # no type to lookup
      if @target.nil? then
        self.class.logging().debug "Considering \"#{argument}\" as variable/string\n"
        @value = argument
        return true
        # need to make sure this variable name points to the correct type in memory
      elsif (@target.include? "int" or @target.include? "integer") and transaction.type_resolve(argument) == :int then
        @value = argument
        return true
      elsif @target.include? "float" and transaction.type_resolve(argument) == :float then
        @value = argument
        return true
      elsif (@target.include? "bool" or @target.include? "boolean") and transaction.type_resolve(argument) == :bool then
        @value = argument
        return true
      end
    elsif is_bool != nil and (@type_restriction.include? "bool" or @type_restriction.include? "boolean") then
      @value = argument
      return true
    end

    return false
  end

  def self.argument?(string)
    log_out = ""
    log_out += "Checking #{string} as DynamicArgument..."
    if string[0] == "{" && string[-1] == "}" && string[1..-2] != nil then
       log_out += " true."
      return true
    end
    log_out += " false."
    logging().debug log_out
    return false
  end
end
