

class Compiler

  def initialize(source_file, dest_file)

    @source_file = source_file
    @dest_file = dest_file

    @externs = []
    @code = []
    @data = {}

    @types = {}

    require_relative "transaction.rb"
    @current_transaction = Transaction.new(compiler: self)

    @kill_bit = 0 # TODO

    # load source file
    src = File.read(source_file).tr("\r","")
    @token_source = src.split("\n")
    @token_index = 0

    # load templates
    require_relative "template_data.rb"
    @template_database = TemplateStorage.new(self)
  end

  def add(transaction)
    @current_transaction = transaction
  end

  def type_resolve(symbol)
    type = nil
    @types.each do |key, value|
      if value.include? symbol then
        return key
      end
    end
    return type
  end

  def has_data(symbol)
    if @data[symbol].nil? then
      return false
    end
  end

  def has_next_line()
    return @token_index < @token_source.length()
  end

  def has_line_after(index:)
    return index < @token_source.length()
  end

  def get_line(index:)
    return nil if !has_line_after(index-1)
    return @token_source[index] if index < @token_source.length()
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

      file.write "\n\nsection .bss align=16\n"
      @bss.each do |key, value|
        file.write value.to_s + "\n"
      end

      file.write "\nsection .data align=16\n"
      @data.each do |key, value|
        file.write value.to_s + "\n"
      end
      file.write "\nglobal main\n"

      file.write "\nsection .text align=16\n"
      file.write "\nmain:\n"
      @code.each do |c|
        file.write c.to_s + "\n"
      end

      file.write "; Program finished. Returning exit code to OS\n"
      file.write "mov rdi, 0\n"
      file.write "call exit\n"
    }
  end

  def compile(transaction: @current_transaction)
    if has_next_line() then
      loop do
        line = next_line()
        break if line.nil?
        transaction.set_index index: @token_index
        @kill_bit = compile_line(transaction: transaction, line: line)
        @token_index = transaction.get_index()
        if @kill_bit == 1 then
          return
        end
      end
    end

    @code = transaction.unpack :code
    @data = transaction.unpack :data
    @externs = transaction.unpack :externs
    @types = transaction.unpack :types
    @bss = transaction.unpack :bss

    @warnings = transaction.unpack :warnings

    finalize(@dest_file)
  end

  def compile_line(transaction: nil, line: nil)
    template = @template_database.find_match(transaction: transaction, line: line)
    if template then
      @template_database.translate(transaction, template, line)
      return 0
    else
      print "\n\nCould not match \"#{line}\" to any templates.  The syntax is probably invalid.\n"
      return 1
    end
  end

  def has_error?()
    return @kill_bit != 0
  end

end


unless ARGV.length == 2 then
  print "\nError: Incorrect number of arguments.\n"
  print "Usage: ruby compiler.rb source_file dest_binary\n"
  exit
end

source_arg = ARGV[0]
dest_binary = ARGV[1]

temp_name = File.join("build", source_arg.split(".")[0])

# Compile to nasm assembly
compiler = Compiler.new(source_arg, temp_name)
compiler.compile()

# If we didn't sucessfully compile
if compiler.has_error? then
  # kill
  print "killed...\n\n"
  exit 1
end # otherwise call assembler and linker


# assemble
assemble_result = `nasm -f elf64 "#{temp_name}" -o "#{temp_name}.o"`

# if assembly success then build/link with C libraries
if assemble_result.length() > 0 then
  # failed to assemble
  print "#{assemble_result}\n\n"
else
  build_result = `gcc -o #{dest_binary} "#{temp_name}.o"`
  if build_result.length() > 0 then
    # failed to build
    print "#{build_result}\n\n"
  else
    print "Build Successful!\n\n"
  end
end
