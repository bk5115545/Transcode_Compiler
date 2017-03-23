class Utils
  def self.whitespace_split_ignore(string)
    return nil if string.nil?
    return string.split(/\b&([^\+\-\*\/\(\)])|([\s(,=\+\-\*\/\(\)])/).reject { |part| part.strip.length == 0 }
  end
end
