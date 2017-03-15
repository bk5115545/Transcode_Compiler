require_relative "simple_template.rb"

# Extension of SimpleTemplate that allows for one or more of the destination registers to be replaced with those provided
# And returns a hash of how the input arguments map to the output arguments
class VariadicTemplate << SimpleTemplate

  def initialize(pattern: "", code_translation: "", data_translation: "", externs: "", bss_translation: "", optimization_level: 1)

    # TODO

  end

  def translate(transaction, input_arguments)
    output_arguments = {}

    # TODO

    return output_arguments
  end

end
