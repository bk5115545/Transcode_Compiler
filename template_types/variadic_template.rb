

class VariadicTemplate

  def initialize(pattern: "", code_translation: "", data_translation: "", externs: "", bss_translation: "", optimization_level: 1)

    # TODO

    @optimization_level = yaml["optimization_level"] || "0"
    @optimization_level = @optimization_level.to_i

    @require_features = yaml["require_features"] || ""
    @require_features = Utils.whitespace_split_ignore(@require_features)

  end

  def full_match?(transaction, line, arguments:[])

    # TODO

  end

  def translate(transaction, input_arguments)
    output_arguments = {}

    # TODO

    return output_arguments
  end

  def get_optimization_level()
    return @optimization_level
  end

  def list_required_features()
    return @require_features
  end

end
