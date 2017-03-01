

class Compiler

    def initialize(source_file, dest_file)

        @externs = []
        @code = []
        @data = {}
        @code_transactions = []
        @data_transactions = []
        @externs_transactions = []
        @code_temp = []
        @data_temp = {}
        @extern_temp = []
        @transaction_counter = 0

        @warnings = []
        @errors = []
        @kill_bit = 0 # TODO

        @token_source = []
        @token_index = 0
        @token_index_temp = 0
        @token_index_transactions = []

        # load templates
        require_relative "template_data.rb"
        @template_database = TemplateStorage.new(self)

        # load source file
        src = File.read(source_file).tr("\r","")
        @token_source = src.split("\n")

        @token_source.each do |target|
            token_lines = target.tr("\r","").split("\n")
            token_lines.each do |line|
                template = @template_database.find_match(line)
                if template then
                    @template_database.translate(self, template, line)
                    match = true
                end

                if !match then
                    print "\n\nCould not match \"#{line}\" to any templates.  The syntax is probably invalid.\n"
                    return
                end
            end
        end

        finalize(dest_file)
    end

    def in_transaction()
        if (@transaction_code.length() > 0 or @transaction_data.length() > 0 or @token_index_transactions.length() > 0) and @transaction_counter == 0 then
            # we somehow have pending transactions but we've closed all transactions to editing
            throw_error("Error when counting transactions in Compiler::in_transaction.  Some basic logic is probably wrong. Code: #{@transaction_code.length()}. Data: #{@transaction_data.length()}. Index: #{@token_index_transactions.length()}.")
        end

        return @transaction_counter > 0
    end

    def add_code(code)
        if in_transaction() then
            @code_temp << code
        else
            @code << code
        end
    end

    def add_data(symbol, code)
        if @data[symbol].nil? then
            @data_temp[symbol] = code if in_transaction()
            @data[symbol] = code if !in_transaction()

            return true
        else
            fail_line = in_transaction() ? @token_index_temp : @token_index
            throw_warning("WARNING: \"#{symbol}\" was to be double-initialized at line: #{fail_line}.  The requested operation has failed.")
            return false
        end
    end

    def add_extern(symbol)
        if in_transaction() then
            if !@externs_temp.include? symbol then
                @externs_temp << symbol
            end
        else
            if !@externs.include? symbol then
                @externs << symbol
            end
        end
        return true
    end


    def has_data(symbol)
        if in_transaction() then
            if @data[symbol].nil? || @data_temp[symbol].nil? then
                return false
            end
        else
            if @data[symbol].nil? then
                return false
            end
        end
        return true
    end

    def has_next_line()
        if !in_transaction() then
            return @token_index - 1 < @token_source.length()
        else
            return @token_index_temp - 1 < @token_source.length()
        end
    end

    def next_line()
        if in_transaction() then
            @token_index_temp += 1
            return @token_source[@token_index_temp]
        else
            @token_index+= 1
            return @token_source[@token_index]
        end
    end

    def transaction_begin()
        if in_transaction() then
            # we're going to nest transactions (which is fine)
            @code_transactions << @code_temp
            @code_temp = []

            @extern_transactions << @externs + @externs_temp

            @data_transactions << @data_temp
            @data_temp = @data.merge(@data_temp) # forward data into transaction to check for variable overwrites

            @token_index_transactions << @token_index_temp
        end

        @transaction_counter += 1
    end

    def in_transaction()
        return @transaction_counter > 0
    end

    def transaction_commit(new_token_index_offset)
        if !in_transaction() then
            throw_error("ERROR: Not in a transaction but transaction_commit was called.  There is an incorrect template used around line #{@token_index} or #{@token_index_temp}")
            return false
        else
            @transaction_counter -= 1
            # we're in nested transactions so add this transaction output to the end of the parents
            if in_transaction() then

                # commit changes to the parent transaction
                @code_transactions[-1] << @code_temp.join("\n")
                @code_data[-1].merge!(@data_temp)

                # this transaction is closed so set active var set to parent transaction
                @code_temp = @code_transactions.last
                @data_temp = @data_transactions.last
                @token_index_temp = @token_index_transactions.last + new_token_index_offset

                # we've moved up the active var set to the parent but we still need to remove the parent from the pending transaction list
                @code_transactions.pop()
                @data_transactions.pop()
                @token_index_transactions.pop()
            else
                # this is the top-level transaction so commit output to generated program
                @code << @code_temp.join("\n")
                @code << "\n\n"
                @code_temp = []
                @data.merge!(@data_temp)
                @data_temp = {}

                # rely on Template to tell us how far to move the compilation token pointer
                @token_index = @token_index_temp + new_token_index_offset
            end
        end

        return true
    end

    def transaction_rollback()
        if !in_transaction() then
            throw_error("ERROR: Not in a transaction but transaction_commit was called.  There is an incorrect template used around line #{@token_index} or #{@token_index_temp}")
            return false
        else
            @transaction_counter -= 1
            # we're in nested transactions so set active to the parents
            if in_transaction() then
                # this transaction is to be abandond so leave some thins behind
                @code_temp = @code_transactions[-1]
                @data_temp = @data_transactions[-1]

                # we've moved up the active var set to the parent but we still need to remove the parent from the pending transaction list
                @code_transactions.pop()
                @data_transactions.pop()
            else
                # there aren't other trasactions to rollback to so we can just forget everything
                @code_temp = []
                @data_temp = @data
                @token_index_temp = @token_index
            end
        end
        return true
    end

    def throw_warning(string)
        # TODO
        print string
        print "\n"
        index = in_transaction() ? @token_index_temp : @token_index
        print "Line #{index}."
        print "\n"
    end

    def throw_error(string, terminate: true)
        # TODO
        print string
        print "\n"
        @kill_bit = 1 if terminate
    end

    def finalize(filename)
        File.open(filename, 'w') { |file|
            file.write "\nsection .data\n"
            @data.each do |key, value|
                file.write value.to_s
            end
            file.write "\nglobal main"

            file.write "\nsection .text"
            file.write "\nmain:"
            @code.each do |c|
                file.write c.to_s
            end

            file.write "; Program finished. Returning exit code to OS\n"
            file.write "mov rdi, 0\n"
            file.write "call exit\n"
        }
    end


end

Compiler.new("test.conv", "ignored/nasm_test/output.asm")
