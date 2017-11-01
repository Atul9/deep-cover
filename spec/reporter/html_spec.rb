require "spec_helper"
require 'deep_cover/reporter/istanbul'

module DeepCover
  module Reporter
    RSpec.describe HTML do
      let(:covered_code){ Node[source].covered_code }
      let(:options) { {} }
      let(:analyser) { Analyser::PerChar.new(covered_code, **options) }
      let(:reporter) { HTML.new(analyser) }

      subject { reporter.source_to_html }

      context 'given a simple code code' do
        let(:source) { '1 || 2' }
        it { should == '<span class="node-int kind-expression run" title="1x">1</span> <span class="node-or kind-operator run" title="1x">' +
                       '||</span> <span class="node-int kind-expression not-run" title="never run">2</span>' }
      end
      context 'escapes <, > and &' do
        let(:source) { ':hello # <escape me> &here' }
        it { should end_with '&lt;escape me&gt; &amp;here' }
      end
    end
  end
end
