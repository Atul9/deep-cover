require "spec_helper"

RSpec::Matchers.define :run_successfully do
  match do |path|
    require 'open3'
    output, errors, status = Open3.capture3('ruby', "spec/full_usage/#{path}")
    @output = output.chomp
    @errors = errors.chomp
    @exit_code = status.exitstatus

    @ouput_ok = @expected_output.nil? || @expected_output == @output

    @exit_code == 0 && @ouput_ok && (@errors == '' || RUBY_PLATFORM == 'java')
  end

  chain :and_output do |output|
    @expected_output = output
  end

  failure_message do
    [
      ("expected output '#{@expected_output}', got '#{@output}'" unless @ouput_ok),
      ("expected exit code 0, got #{@exit_code}" if @exit_code != 0),
      ("expected no errors, got '#{@errors}'" unless @errors.empty?),
    ].compact.join(' and ')
  end
end

RSpec.describe 'DeepCover usage' do
  it { 'simple/simple.rb'.should run_successfully.and_output('Done') }
  it { 'with_configure/test.rb'.should run_successfully.and_output('[1, 0, 2, 0, nil, 2, nil, nil]') }

  it 'Can still require gems when there is no bundler' do
    ignore_output = {in: File::NULL, out: File::NULL, err: File::NULL}
    Bundler.with_clean_env do
      install_success = system("gem install --local spec/full_usage/tiny_gem-0.1.0.gem", ignore_output)
      install_success.should be true

      require_success = system(%(ruby -e 'require "./lib/deep_cover"; DeepCover.start; require "tiny_gem"'), ignore_output)
      require_success.should be true
    end
  end

end
