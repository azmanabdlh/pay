# frozen_string_literal: true

require "rails/generators"

module Pay
  module Generators
    class ViewsGenerator < Rails::Generators::Base
      source_root File.expand_path("../../..", __dir__)

      def copy_views
        directory "app/views/pay", "app/views/pay"
      end
    end
  end
end
