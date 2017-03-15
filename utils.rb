class Utils
  def self.whitespace_split_ignore(string)
    return string.split(/\b&([^\+\-\*\/\(\)])|([\s(,=\+\-\*\/\(\)])/).reject { |part| part.strip.length == 0 }
  end
end
