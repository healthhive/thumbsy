# frozen_string_literal: true

module Thumbsy
  class InvalidFeedbackOptionError < ArgumentError; end
end

module ActiveModel
  module Validations
    class ArrayInclusionValidator < EachValidator
      def validate_each(record, attribute, value)
        return if value.nil?

        allowed = options[:in] || []
        return if value.is_a?(Array) && value.all? { |v| allowed.include?(v) }

        record.errors.add(attribute, "contains invalid feedback option(s)")
      end
    end
  end
end
