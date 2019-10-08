source 'https://rubygems.org'

# Specify your gem's dependencies in friendly_id-mobility.gemspec
gemspec

group :development, :test do
  gem 'rake'

  gem 'sqlite3'

  if ENV['RAILS_VERSION'] == '6.0'
    gem 'rails', '>= 6.0', '< 6.1'
  elsif ENV['RAILS_VERSION'] == '5.2'
    gem 'rails', '>= 5.2', '< 6.0'
  elsif ENV['RAILS_VERSION'] == '5.1'
    gem 'rails', '>= 5.1', '< 5.2'
  elsif ENV['RAILS_VERSION'] == '5.0'
    gem 'rails', '>= 5.0', '< 5.1'
  else
    gem 'rails', '>= 6.1', '< 6.2'
  end

  gem 'pry'
  gem 'pry-byebug'
end
