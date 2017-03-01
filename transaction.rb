class Transaction

    def initialize(compiler:, defaults: {}, parent: nil)
        @compiler = compiler
        @tracked = defaults.dup
        @parent = parent
    end

    def create_child()
        return Transaction.new(defaults: @tracked, parent: self)
    end

    def commit()
        if @parent == nil then
            @compiler.add self
        else
            @tracked.each do |key, value|
                @parent.add symbol: key, addition: value, verify_unique: false if key == "code"
            end
        end
    end

    def add(symbol:, addition:, verify_unique: false)
        symbol = symbol.to_s
        if verify_unique then
            if addition.is_a(String) then
                if @tracked[symbol].include? addition then
                    @compiler.throw_warning "Tried to add \"#{addition}\" when it should only be in the binary once."
                else
                    @tracked[symbol] << addition
                end
            else
                # data is a hash instead of an array
                if addition.is_a(Hash) then
                    addition.each do |key, value|
                        if @tracked[symbol].has_key(key) then
                            @compiler.throw_warning "Tried to add \"#{addition}\" when it should only be in the binary once."
                        else
                            @tracked[symbol][key] = value
                        end
                    end
                elsif addition.is_a(Array) then
                    addition.each do |value|
                        if !@tracked[symbol].include? value then
                            @tracked[symbol] << value
                        else
                            @compiler.throw_warning "Tried to add \"#{addition}\" when it should only be in the binary once."
                        end
                    end
                else
                    return false
                end
                return true
            end
        else
            if addition.is_a(String) then
                @tracked[symbol] << addition
            elsif addition.is_a(Hash) then
                addition.each do |key, value|
                    @tracked[symbol][key] = value
                end
            elsif addition.is_a(Array) then
                addition.each do |value|
                    @tracked[symbol] << value
                end
            else
                return false
            end
            return true
        end
    end
end
