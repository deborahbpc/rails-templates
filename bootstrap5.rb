run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# Gems
########################################
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
    gem 'font-awesome-sass'
    gem 'bootstrap', '~> 5.0.0.beta1'
    gem 'jquery-rails'
    gem 'hotwire-rails'
    gem 'hotwire-stimulus-rails'
    gem 'turbo-rails'
    \n
  RUBY
end

gsub_file('Gemfile', /# gem 'rails'/, "'rails', '~> 6.1'")

inject_into_file 'Gemfile', after: 'group :development, :test do' do
  <<-RUBY
  gem 'dotenv-rails'
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'capybara'
  gem 'rspec-rails'
  gem 'database_cleaner'
  gem 'factory_bot_rails'
  RUBY
end

# Assets
########################################
run 'rm -rf app/assets/stylesheets/application.css'
run 'touch app/assets/stylesheets/application.scss'
run 'mkdir app/assets/stylesheets/components'
run 'touch app/assets/stylesheets/components/_index.scss'
run 'mkdir app/assets/stylesheets/config'
run 'touch app/assets/stylesheets/config/_index.scss'
run 'touch app/assets/stylesheets/config/_colors.scss'
run 'touch app/assets/stylesheets/config/_fonts.scss'

append_file 'app/assets/stylesheets/config/_index.scss', <<~CSS
  @import "colors";
  @import "fonts";
CSS

append_file 'app/assets/stylesheets/application.scss', <<~CSS
  @import "config/index";
  @import "components/index";
  @import "bootstrap";
CSS

after_bundle do
  # DB
  ########################################
  rails_command 'db:drop db:create db:migrate'

  # Tests
  ########################################
  generate('rspec:install')
  gsub_file('spec/rails_helper.rb', /config.use_transactional_fixtures = true/, 'config.use_transactional_fixtures = false')
  inject_into_file 'spec/rails_helper.rb', after: 'config.use_transactional_fixtures = false' do
    <<-RUBY
      \n
      config.before(:suite) do
        DatabaseCleaner.strategy = :transaction
        DatabaseCleaner.clean_with(:truncation)
        DatabaseCleaner.start
        DatabaseCleaner.clean
      end

      config.before(:each) do
        DatabaseCleaner.clean
      end

      config.after(:each) do
        DatabaseCleaner.clean
      end

      config.after(:suite) do
        DatabaseCleaner.clean
      end

      config.include Devise::Test::ControllerHelpers, type: :controller
      config.include FactoryBot::Syntax::Methods
    RUBY
  end

  # Hotwire
  run 'rails hotwire:install'

  # For Bootstrap in Rails 6.1
  ########################################
  run 'yarn add bootstrap@next @popperjs/core'

  inject_into_file 'app/views/layouts/application.html.erb', after: '<%= stimulus_include_tags %>' do
    <<~HTML
      \n
          <%= stylesheet_pack_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
      \n
    HTML
  end

  run 'mkdir app/javascript/stylesheets'
  run 'touch app/javascript/stylesheets/application.scss'

  append_file 'app/javascript/stylesheets/application.scss', <<~CSS
    @import "bootstrap";
  CSS

  append_file 'app/javascript/packs/application.js', <<~JS
    import * as bootstrap from "bootstrap";
    import "../stylesheets/application";
    #{'    '}
    document.addEventListener("DOMContentLoaded", function(event) {
        var popoverTriggerList = [].slice.call(
            document.querySelectorAll('[data-bs-toggle="popover"]')
        );
        var popoverList = popoverTriggerList.map(function(popoverTriggerEl) {
            return new bootstrap.Popover(popoverTriggerEl);
        });
    #{'    '}
        var tooltipTriggerList = [].slice.call(
            document.querySelectorAll('[data-bs-toggle="tooltip"]')
        );
        var tooltipList = tooltipTriggerList.map(function(tooltipTriggerEl) {
            return new bootstrap.Tooltip(tooltipTriggerEl);
        });
    });
  JS

  # Git ignore
  ########################################
  append_file '.gitignore', <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Shared views directory
  ########################################
  run 'mkdir app/views/shared'

  # Dotenv
  ########################################
  run 'touch .env'

  # Rubocop
  ########################################
  run 'curl -L https://raw.githubusercontent.com/edcolen/rails-templates/master/.rubocop.yml > .rubocop.yml'
end
