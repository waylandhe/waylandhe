source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.0.0"

gem "rails", "~> 7.0.7"
gem "sprockets-rails"
gem "puma", "~> 5.0"
gem "importmap-rails"
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# YNAB API client
gem "ynab"

group :development, :test do
  gem "pry"
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem "dotenv-rails"
end

group :development do
  gem "web-console"
end
