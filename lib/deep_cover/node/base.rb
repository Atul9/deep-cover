require 'backports/2.1.0/enumerable/to_h'

module DeepCover
  # Base class to handle covered nodes.
  class Node < Parser::AST::Node
    include HasChild
    attr_reader :file_coverage, :index, :nb, :parent

    def initialize(base_node, file_coverage, parent, index = 0)
      @file_coverage = file_coverage
      augmented_children = base_node.children.map.with_index { |child, child_index| self.class.augment(child, file_coverage, self, child_index) }
      @nb = file_coverage.create_node_nb
      @tracker_offset = file_coverage.allocate_trackers(self.class::TRACKERS.size).begin
      @parent = parent
      @index = index
      super(base_node.type, augmented_children, location: base_node.location)
    end

    ### High level API for coverage purposes

    # Returns an array of character numbers (in the original buffer) that
    # pertain exclusively to this node (and thus not to any children).
    def proper_range
      return [] unless location
      full_range - children_nodes.flat_map(&:full_range)
    end

    def full_range
      return [] unless location
      location.expression.to_a
    end

    def [](v)
      children[v]
    end

    # Returns true iff it is executable and if was successfully executed
    def was_executed?
      # There is a rare case of non executable nodes that have important data in flow_entry_count / flow_completion_count,
      # like `if cond; end`, so make sure it's actually executable first...
      executable? && execution_count > 0
    end

    # Returns the control flow entered the node.
    # The control flow can then either complete normally or be interrupted
    #
    # Implementation: This is always the responsibility of the parent; Nodes should not override.
    def flow_entry_count
      parent.child_flow_entry_count(self)
    end

    # Returns the number of times it changed the usual control flow (e.g. raised, returned, ...)
    # Implementation: This is always deduced; Nodes should not override.
    def flow_interrupt_count
      flow_entry_count - flow_completion_count
    end

    ### These are refined by subclasses

    # Returns true iff it is executable. Keywords like `end` are not executable, but literals like `42` are executable.
    def executable?
      true
    end

    # Returns number of times the node itself was "executed". Definition of executed depends on the node.
    def execution_count
      flow_entry_count
    end

    # Returns the number of times the control flow succesfully left the node.
    # This is the responsability of the child Node, never of the parent.
    # Must be refined if the child node may have an impact on control flow (raising, branching, ...)
    def flow_completion_count
      last = children_nodes.last
      return last.flow_completion_count if last
      flow_entry_count
    end

    # Returns the number of time the control flow entered this child_node.
    # This is the responsability of the Node, not of the child.
    # Must be refined if the parent node may have an impact on control flow (raising, branching, ...)
    def child_flow_entry_count(child)
      call_handler('%{name}_flow_entry_count', child) do
        prev = child.previous_sibling
        if prev
          prev.flow_completion_count
        else
          flow_entry_count
        end
      end
    end

    # Code to add before the node for covering purposes (or `nil`)
    def prefix
    end

    def child_prefix(child)
    end

    def full_prefix
      "#{prefix}#{parent.child_prefix(self)}"
    end

    # Code to add after the node for covering purposes (or `nil`)
    def suffix
    end

    def child_suffix(child)
    end

    def full_suffix
      "#{parent.child_suffix(self)}#{suffix}"
    end

    ### Singleton methods
    class << self

      ### These are refined by subclasses

      # Returns a subclass or the base Node, according to type
      def factory(type)
        class_name = type.capitalize
        const_defined?(class_name) ? const_get(class_name) : Node
      end

      ### Public API

      # Augment creates a covered node from the child_base_node.
      def augment(child_base_node, file_coverage, parent, child_index = 0)
        # Skip children that aren't node themselves (e.g. the `method` child of a :def node)
        return child_base_node unless child_base_node.is_a? Parser::AST::Node
        klass = factory(child_base_node.type)
        klass.new(child_base_node, file_coverage, parent, child_index)
      end

      ### Internal

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
    has_trackers

    ### Public API

    def children_nodes
      children.select{|c| c.is_a? Node }
    end

    def next_sibling
      parent.children[(@index+1)..-1].detect { |sibling| sibling.is_a?(Node) }
    end

    def previous_sibling
      parent.children[0...@index].reverse.detect { |sibling| sibling.is_a?(Node) }
    end

    ### Internal API

    def each_node(order = :postorder, &block)
      return to_enum :each_node, order unless block_given?
      yield self unless order == :postorder
      children_nodes.each do |child|
        child.each_node(order, &block)
      end
      yield self if order == :postorder
      self
    end

    def each_branch(order = :postorder, &block)
      return to_enum :each_branch, order unless block_given?
      each_node(order) { |node| yield node if node.is_a? Branch }
    end

    def line_cover
      return unless ex = loc && loc.expression
      file_coverage.line_hit(ex.line - 1, flow_entry_count)
      children_nodes.each(&:line_cover)
    end

    def fancy_type
      class_name = self.class.to_s.rpartition('::').last
      t = super
      t.casecmp(class_name) == 0 ? t : "#{t}[#{class_name}]"
    end

  end
end
