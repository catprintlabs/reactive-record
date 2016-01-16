module ReactiveRecord

  module Pry

    def self.rescue(&block)
      if defined? PryRescue
        ::Pry::rescue &block
      else
        block.call
      end
    end

    def self.rescued(e)
      ::Pry::rescued(e) if defined?(PryRescue) && !e.is_a?(ReactiveRecord::AccessViolation)
    end

  end

end
