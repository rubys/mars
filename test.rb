Dir['test/*.rb'].each {|test| require test}

begin
  Dir['tools/*.spec'].each {|spec| load spec}
rescue LoadError
  STDERR.puts "test/spec not found, skipping #{Dir['tools/*.spec'].join(', ')}"
end
