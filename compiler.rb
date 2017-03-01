

class Compiler

  def initialize(source_file, dest_file)

    @externs = []
    @code = []
    @data = {}

    require_relative "transaction.rb"
    @current_transaction = Transaction.new(compiler: self)

    @kill_bit = 0 # TODO

    @token_source = []
    @token_index = 0

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
          @template_database.translate(@current_transaction, template, line)
          match = true
        end

        if !match then
          print "\n\nCould not match \"#{line}\" to any templates.  The syntax is probably invalid.\n"
          return
        end
      end
    end

    @code = @current_transaction.unpack :code
    @data = @current_transaction.unpack :data
    @externs = @current_transaction.unpack :externs

    @warnings = @current_transaction.unpack :warnings
    print_warnings()

    finalize(dest_file)
  end

  def add(transaction)
    @current_transaction = transaction
  end

  def add_code(code)
    if code.is_a?(Array) then
      code.each { |val| @code << val }
      return true
    end

    return false
  end

  def add_data(symbol, code)
    # uniqueness check happens in the transaction that called this method
    @data[symbol] << code
  end

  def add_extern(symbol)
    if !@externs.include? symbol then
      @externs << symbol
    end
  end


  def has_data(symbol)
    if @data[symbol].nil? then
      return false
    end
  end

  def has_next_line()
    return @token_index - 1 < @token_source.length()
  end

  def next_line()
    return nil if !has_next_line()
    @token_index += 1
    return @token_source[@token_index]
  end

  def print_warnings()
    @warnings.each do |warning|
      print warning.to_s + "\n\n"
    end
  end


  def finalize(filename)
    File.open(filename, 'w') { |file|

      file.write "extern " + @externs.uniq.join(", ") + "\n" if @externs.uniq.length > 0

      file.write "\nsection .data\n"
      @data.each do |key, value|
        file.write value.to_s + "\n"
      end
      file.write "\nglobal main"

      file.write "\nsection .text"
      file.write "\nmain:\n"
      @code.each do |c|
        file.write c.to_s + "\n"
      end

      file.write "; Program finished. Returning exit code to OS\n"
      file.write "mov rdi, 0\n"
      file.write "call exit\n"
    }
  end


end


unless ARGV.length == 2 then
  print "Error: Incorrect number of arguments.\n"
  print "Usage: ruby compiler.rb source_file dest_binary"
  exit
end

source_arg = ARGV[0]
dest_binary = ARGV[1]

temp_name = File.join("build", source_arg.split(".")[0])

# Compile to nasm assembly
Compiler.new(source_arg, temp_name)


# assemble
assemble_result = `nasm -f elf64 "#{temp_name}" -o "#{temp_name}.o"`

# if assembly success then build/link with C libraries
if assemble_result.length() > 0 then
  # failed to assemble
  print assemble_result
else
  build_result = `gcc -o #{dest_binary} "#{temp_name}.o"`
  if build_result.length() > 0 then
    # failed to build
    print build_result
  else
    print "Build Successful!\n\n"
  end
end
