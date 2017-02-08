class Tokenizer

    def initialize()
    end

    def self.tokenize(string)
        return string.tr("\r","").split("\n")
    end

end
