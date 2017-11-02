module DeepCover
  module Memoized
    def self.included(base)
      base.extend ClassMethods
    end

    def freeze
      self.class.memoized.each do |method|
        send method
      end
      super
    end

    module ClassMethods
      def memoize(*methods)
        memoized = instance_methods(false).reject{|m| instance_method(m).arity > 0} if methods.empty?
        define_singleton_method(:memoized) { memoized }
        mod = _create_memoizer
        const_set :Memoizer, mod
        prepend mod
      end

      private
      def _create_memoizer
        mod = Module.new
        memoized.each do |method|
          mod.module_eval <<-RUBY
            def #{method}(*args)
              return super if block_given? || !args.empty?
              @_cache_#{method} ||= super
            end
          RUBY
        end
        mod
      end
    end
  end

  module Tools::Memoize
    def memoize(klass, *methods)
      klass.include Memoized
      klass.memoize *methods
    end
  end
end
