module DeepCover
  module Reporter
    class HTML < Struct.new(:analyser, :options)
      def self.render_template(template, binding)
        require 'erb'
        template = Pathname.new(__dir__).join("html/#{template}.html.erb").read
        erb = ERB.new(template)
        erb.result(binding)
      end

      class Site < Struct.new(:covered_codes, :options)
        def path
          options[:output]
        end

        def save
          clear
          compile_stylesheet
          save_assets
          save_index
          save_pages
        end

        def clear
          path.mkpath
          path.rmtree
          path.mkpath
        end

        def compile_stylesheet
          Bundler.with_clean_env do
            `sass #{__dir__}/html/deep_cover.css.sass #{__dir__}/html/assets/deep_cover.css` rescue nil
          end
        end

        def build_index
          names = covered_codes.map(&:name)
          HTML.render_template(:index, binding)
        end

        def save_index
          path.join('index.html').write(build_index)
        end

        def save_assets
          path.join('assets').mkpath
          path.join('assets/deep_cover.css').write(File.read("#{__dir__}/html/assets/deep_cover.css"))
        end

        def save_pages
          covered_codes.each do |covered_code|
            dest = path.join("#{covered_code.name}.html")
            dest.dirname.mkpath
            dest.write(HTML.new(analysis[covered_code][:per_char], root_path: path.relative_path_from(dest.dirname)).report)
          end
        end

        def analysis(covered_code = nil)
          if covered_code
            base = Analyser::Node.new(covered_code, **options)
            { per_char: Analyser::PerChar, branch: Analyser::Branch }.map do |type, klass|
              [type, klass.new(covered_code, **options)]
            end.to_h.merge!(node: base)
          else
            @analysis ||= covered_codes.map do |covered_code|
              [covered_code, analysis(covered_code)]
            end.to_h
          end
        end

        def stats(covered_code = nil)
          if covered_code
            stats[covered_code]
          else
            @stats ||= analysis.transform_values{|analysis| analysis.transform_values(&:stats)}
          end
        end
      end

      def self.save(covered_codes, output: raise, **options)
        Site.new(covered_codes, output: output, **options).save
      end

      def node_attributes(node, kind)
        title, run = case runs = analyser.node_runs(node)
        when nil
          ['ignored', 'ignored']
        when 0
          ['never run', 'not-run']
        else
          ["#{runs}x", 'run']
        end
        %Q{class="node-#{node.type} kind-#{kind} #{run}" title="#{title}"}
      end

      def convert
        @rewriter = ::Parser::Source::Rewriter.new(analyser.covered_code.buffer)
        insert_tags
        html_escape
        @rewriter.process
      end

      def report
        HTML.render_template(:source, binding)
      end

      private

      def insert_tags
        analyser.each_node do |node, _children|
          node.executed_loc_hash.each do |kind, range|
            @rewriter.insert_before_multi(range, "<span #{node_attributes(node, kind)}>")
            @rewriter.insert_after_multi(range, '</span>')
          end
        end
      end

      def each_match(source, pattern) # Is there really no builtin way to do this??
        prev = 0
        while (m = source.match(pattern, prev)) do
          yield m
          prev = m.end(0)
        end
      end

      def html_escape
        buffer = analyser.covered_code.buffer
        source = buffer.source
        {'<' => '&lt;', '>' => '&gt;', '&' => '&amp;'}.each do |char, escaped|
          each_match(source, char) do |match|
            @rewriter.replace(::Parser::Source::Range.new(buffer, match.begin(0), match.end(0)), escaped)
          end
        end
      end
    end
  end
end
