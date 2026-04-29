source "https://rubygems.org"

# GitHub Pages — versão oficial usada pelo GitHub para build
gem "github-pages", group: :jekyll_plugins

# Plugins do Jekyll
group :jekyll_plugins do
  gem "jekyll-feed"
  gem "jekyll-seo-tag"
  gem "jekyll-sitemap"
  gem "jekyll-paginate"
end

# Dependências de plataforma
platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end

gem "wdm", "~> 0.1.1", :platforms => [:mingw, :x64_mingw, :mswin]
gem "http_parser.rb", "~> 0.6.0", :platforms => [:jruby]

# Necessário a partir do Ruby 3.0
gem "webrick", "~> 1.8"
