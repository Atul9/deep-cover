module DeepCover
  class Analyser::PerChar < Analyser
    # Returns an array of characters for each line of code.
    # Each character is either ' ' (executed), '-' (not executable) or 'x' (not covered)
    def results
      buffer = covered_code.buffer
      bc = buffer.source_lines.map{|line| '-' * line.size}
      each_node do |node, _children|
        runs = node_runs(node)
        if runs != nil
          node.proper_range.each do |pos|
            bc[buffer.line_for_position(pos)-1][buffer.column_for_position(pos)] = runs > 0 ? ' ' : 'x'
          end
        end
      end
      bc.zip(buffer.source_lines){|cov, line| cov[line.size..-1] = ''} # remove extraneous character for end lines, in any
      bc
    end
  end
end
