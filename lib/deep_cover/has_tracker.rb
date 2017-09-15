module DeepCover
  module HasTracker
    def self.included(base)
      base.extend ClassMethods
    end

    def assign_properties(*)
      @tracker_offset = file_coverage.allocate_trackers(self.class::TRACKERS.size).begin
      super
    end

    module ClassMethods
      def has_trackers(*names)
        const_set :TRACKERS, names.each_with_index.to_h
        names.each_with_index do |name, i|
          class_eval <<-end_eval, __FILE__, __LINE__
            def #{name}_tracker_source
              file_coverage.tracker_source(@tracker_offset + #{i})
            end
            def #{name}_tracker_hits
              file_coverage.tracker_hits(@tracker_offset + #{i})
            end
          end_eval
        end
      end

      def has_tracker(tracker) # Allow singular form
        has_trackers(tracker)
      end
    end
  end
end