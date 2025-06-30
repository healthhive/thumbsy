# frozen_string_literal: true

module Thumbsy
  module Extension
    def votable(_options = {})
      include Thumbsy::Votable
    end

    def voter(_options = {})
      include Thumbsy::Voter
    end
  end
end
