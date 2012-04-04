# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard 'puma' do
  watch('Gemfile.lock')
  watch(%r{^config|lib/.*})
end

guard 'minitest', :test_file_patterns => '*_test.rb' do
  watch(%r|^test/(.*)_test\.rb|)
  watch(%r{^api/(.*/)?([^/]+)\.rb$})  { |m| "test/api/#{m[1]}#{m[2]}_test.rb" }
  watch(%r|^test/test_helper\.rb|)    { "test" }
end
