# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard 'rspec', :version => 2, :cli => '--colour', :notification => true do
  watch(%r{^spec/.+_spec\.rb})
  watch(%r{^lib/(.+)\.rb})                      { |m| "spec/message_router_spec.rb" }
  watch(/^spec\/spec_helper.rb/)                { "spec" }
end