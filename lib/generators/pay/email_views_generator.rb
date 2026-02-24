# frozen_string_literal: true

require "rails/generators"

module Pay
  module Generators
    class EmailViewsGenerator < Rails::Generators::Base
      source_root File.expand_path("../../..", __dir__)

      def copy_views
        directory "app/views/pay/user_mailer", "app/views/pay/user_mailer"
      end
    end
  end
end
