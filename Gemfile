source "https://rubygems.org"

gem "rails", "~> 8.1"
gem "puma", "~> 7.2"

# DELIBERATELY VULNERABLE: test for Dependency Review (guide section 13).
# rubyzip 1.2.1 has known advisories (CVE-2018-1000544, CVE-2019-16892, CVE-2026-85396).
# Never merge this branch. The app never loads this gem.
gem "rubyzip", "1.2.1", require: false

group :development, :test do
  gem "brakeman", require: false
end
