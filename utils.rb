class Utils
  def self.whitespace_split_ignore(string)
    return string.split(/\s|\b&[^.,]|\s|(,)/).reject { |part| part.length == 0 }
  end
end
