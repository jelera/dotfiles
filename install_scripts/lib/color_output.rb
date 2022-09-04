# frozen_string_literal: true

module ColorOutput
  TERM_COLORS = {
    red: 31,
    green: 32,
    blue: 34
  }

  def self.call(color = :green, padding: true)
    puts if padding
    printf "\033[#{TERM_COLORS.fetch(color)}m";
    yield
    printf "\033[0m"
    puts if padding
  end
end
