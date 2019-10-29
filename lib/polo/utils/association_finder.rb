module Polo::Utils
  class AssociationFinder

    attr_reader :entry_point, :max_level, :include_polymorphic, :blacklist

    def self.run(*args)
      new(*args).run
    end

    def initialize(entry_point, max_level: 2, include_polymorphic: true, blacklist: [])
      @entry_point = entry_point
      @max_level = max_level
      @include_polymorphic = include_polymorphic
      @blacklist = blacklist
    end

    def run
      if defined?(Rails)
        Rails.configuration.eager_load_namespaces.each(&:eager_load!) unless Rails.env.production?
      end
      root = {}

      q = entry_point.reflect_on_all_associations.map { |i| [root, i, 0] }

      visited = [entry_point]

      while (element = q.shift)
        node, assoc, level = element
        next if blacklist.include?(assoc.name)

        if assoc.polymorphic?
          puts "Skipping #{assoc.name} of #{assoc.active_record} (polymorphic)"
          node[assoc.name] = {} if include_polymorphic
          next
        end
        other_class = assoc.compute_class assoc.class_name

        if visited.include?(other_class)
          if assoc.is_a?(ActiveRecord::Reflection::HasAndBelongsToManyReflection) and other_class != entry_point
            node[assoc.name] = {}
          end
          next
        end
        visited << other_class

        subtree = node[assoc.name] = {}
        next unless level < max_level

        other_class.reflect_on_all_associations.each do |new_assoc|
          q << [subtree, new_assoc, level + 1]
        end
      end
      root
    end
  end
