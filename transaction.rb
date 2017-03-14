class Transaction

  require_relative "utils.rb"

  def initialize(compiler:, defaults: {"code" => [], "data" => {}, "externs" => ["exit"], "types" => {}, "bss" => {} }, parent: nil)
    @warnings = []
    @compiler = compiler
    @tracked = defaults.dup
    @parent = parent
  end

  def create_child()
    return Transaction.new(defaults: @tracked, parent: self)
  end

  def commit()
    @warnings.each do |warning|
      print warning.to_s + "\n"
    end

    if @parent == nil then
      @compiler.add self
    else
      @tracked.each do |key, value|
        @parent.add symbol: key, text: value, verify_unique: false if key == "code"
      end
    end
  end

  def whitespace_split_ignore(string)
    return Utils.whitespace_split_ignore(string)
  end

  def add_bss(text:, verify_unique: false)
    if verify_unique then

    else
      if text.is_a?(Hash) then
        # Hash => {varname, [type, assembly]}
        text.each do |key, value|
          if value.is_a?(Array) then
            type = value[0]
            value = value[1]
          end
          @tracked["bss"][key] = value
          if @tracked["types"][type].nil? then
            @tracked["types"][type] = []
          end
          @tracked["types"][type] << key
        end
      end
    end
  end

  def add(symbol:, text:, verify_unique: false)
    symbol = symbol.to_s
    if verify_unique then
      if text.is_a?(String) then
        if @tracked[symbol].include? text then
          throw_warning "Tried to add \"#{text}\" when it should only be in the binary once."
        else
          @tracked[symbol] << text
        end
      else
      # data is a hash instead of an array
      if text.is_a?(Hash) then
        text.each do |key, value|
          # if there's a type specified we want to track it too
          if value.is_a?(Array) then
            type = value[0]
            value = value[1]
          end

          if @tracked[symbol].has_key(key) then
            throw_warning "Tried to add \"#{text}\" when it should only be in the binary once."
          else
            @tracked[symbol][key] = value

            if @tracked["types"][type].nil? then
              @tracked["types"][type] = []
            end
            @tracked["types"][type] << key
          end
        end
      elsif text.is_a?(Array) then
        text.each do |value|
          if !@tracked[symbol].include? value then
            @tracked[symbol] << value
          else
            throw_warning "Tried to add \"#{text}\" when it should only be in the binary once."
          end
        end
      else
        return false # didn't add anyting
      end

      return true # added something
      end
  else
    if text.is_a?(String) then
      @tracked[symbol] << text

    elsif text.is_a?(Hash) then
      text.each do |key, value|
        if value.is_a?(Array) then
          type = value[0]
          value = value[1]
        end
        @tracked[symbol][key] = value
        if @tracked["types"][type].nil? then
          @tracked["types"][type] = []
        end
        @tracked["types"][type] << key
      end

    elsif text.is_a?(Array) then
      text.each do |value|
        @tracked[symbol] << value
      end

    else
      return false # didn't add anything
    end

    return true # added something
    end
  end

  def type_resolve(symbol)
    print "Searching for type_of: #{symbol}... "
    @tracked["types"].each { |key, value|
      print "#{key}: #{value}"
      if value.include? symbol then
        return key.to_sym
      end
    }
    return nil
  end

  def throw_warning(text)
    @warnings << "WARNING: Line #{@token_index}: " + text.to_s
  end

  def unpack(symbol)
    return @warnings if symbol.to_s == "warnings"

    return @tracked[symbol.to_s]
  end

end
