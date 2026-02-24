# frozen_string_literal: true

module Pay
  module Resolvable
    extend ActiveSupport::Concern

    def resolve_pay_klass(processor_name, type)
      klass = "Pay::#{processor_name.to_s.classify}::#{type}"
      klass = "Pay::#{processor_name.to_s.camelize}::#{type}" if klass.safe_constantize.nil?

      klass.constantize
    end

    def klass_for_object
    end
  end
end
