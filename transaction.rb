class Transaction

    def initialize(compiler:, defaults: {"code" => [], "data" => {}, "externs" => []}, parent: nil)
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
            if @tracked[symbol].has_key(key) then
              throw_warning "Tried to add \"#{text}\" when it should only be in the binary once."
            else
              @tracked[symbol][key] = value
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
          @tracked[symbol][key] = value
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

    def throw_warning(text)
      @warnings << "WARNING: Line #{@token_index}: " + text.to_s
    end

    def unpack(symbol)
      return @warnings if symbol.to_s == "warnings"

      return @tracked[symbol.to_s]
    end

end
