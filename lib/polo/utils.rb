require "polo/utils/version"

require 'polo'
require 'polo/utils/association_finder'
module Polo
  module Utils
    module_function

    # generates sql with ALL associations
    def extract(klass, id, max_level: 1, blacklist: [])
      klass = klass.is_a?(String) ? klass.constantize : klass
      associations = Polo::Utils::AssociationFinder.run(klass, max_level: 3, blacklist: blacklist)

      Polo.configure do
        @adapter = if ActiveRecord::Base.configurations[Rails.env.to_s]['adapter'] == :postgresql
                     :postgres
                   else
                     :mysql
                   end
        on_duplicate :override
      end
      Polo.explore(klass, id.to_i, associations)
    end
  end
end
