# frozen_string_literal: true
# Rails template to build the sample app for specs

gem "cssbundling-rails"

create_file "app/assets/config/manifest.js"

rails_command "css:install:tailwind"
# Remove default configuration generated: https://github.com/rails/cssbundling-rails/blob/v1.4.2/lib/install/tailwind/install.rb#L7
remove_file "app/assets/stylesheets/application.tailwind.css"
remove_file "tailwind.config.js"

rails_command "importmap:install"

initial_timestamp = Time.now.strftime("%Y%m%d%H%M%S").to_i

template File.expand_path("templates/migrations/create_posts.tt", __dir__), "db/migrate/#{initial_timestamp}_create_posts.rb"

copy_file File.expand_path("templates/models/post.rb", __dir__), "app/models/post.rb"
copy_file File.expand_path("templates/post_decorator.rb", __dir__), "app/models/post_decorator.rb"
copy_file File.expand_path("templates/post_poro_decorator.rb", __dir__), "app/models/post_poro_decorator.rb"

template File.expand_path("templates/migrations/create_blog_posts.tt", __dir__), "db/migrate/#{initial_timestamp + 1}_create_blog_posts.rb"

copy_file File.expand_path("templates/models/blog/post.rb", __dir__), "app/models/blog/post.rb"

template File.expand_path("templates/migrations/create_profiles.tt", __dir__), "db/migrate/#{initial_timestamp + 2}_create_profiles.rb"

copy_file File.expand_path("templates/models/user.rb", __dir__), "app/models/user.rb"

template File.expand_path("templates/migrations/create_users.tt", __dir__), "db/migrate/#{initial_timestamp + 3}_create_users.rb"

copy_file File.expand_path("templates/models/profile.rb", __dir__), "app/models/profile.rb"

copy_file File.expand_path("templates/models/publisher.rb", __dir__), "app/models/publisher.rb"

template File.expand_path("templates/migrations/create_categories.tt", __dir__), "db/migrate/#{initial_timestamp + 4}_create_categories.rb"

copy_file File.expand_path("templates/models/category.rb", __dir__), "app/models/category.rb"

copy_file File.expand_path("templates/models/store.rb", __dir__), "app/models/store.rb"
template File.expand_path("templates/migrations/create_stores.tt", __dir__), "db/migrate/#{initial_timestamp + 5}_create_stores.rb"

template File.expand_path("templates/migrations/create_tags.tt", __dir__), "db/migrate/#{initial_timestamp + 6}_create_tags.rb"

copy_file File.expand_path("templates/models/tag.rb", __dir__), "app/models/tag.rb"

template File.expand_path("templates/migrations/create_taggings.tt", __dir__), "db/migrate/#{initial_timestamp + 7}_create_taggings.rb"

copy_file File.expand_path("templates/models/tagging.rb", __dir__), "app/models/tagging.rb"

copy_file File.expand_path("templates/helpers/time_helper.rb", __dir__), "app/helpers/time_helper.rb"

copy_file File.expand_path("templates/models/company.rb", __dir__), "app/models/company.rb"
template File.expand_path("templates/migrations/create_companies.tt", __dir__), "db/migrate/#{initial_timestamp + 8}_create_companies.rb"
template File.expand_path("templates/migrations/create_join_table_companies_stores.tt", __dir__), "db/migrate/#{initial_timestamp + 9}_create_join_table_companies_stores.rb"

inject_into_file "app/models/application_record.rb", before: "end" do
  <<-RUBY

  def self.ransackable_attributes(auth_object=nil)
    authorizable_ransackable_attributes
  end

  def self.ransackable_associations(auth_object=nil)
    authorizable_ransackable_associations
  end
  RUBY
end

environment 'config.hosts << ".ngrok-free.app"', env: :development

# Make sure we can turn on class reloading in feature specs.
# Write this rule in a way that works even when the file doesn't set `config.cache_classes` (e.g. Rails 7.1).
gsub_file "config/environments/test.rb", /  config.cache_classes = true/, ""
inject_into_file "config/environments/test.rb", after: "Rails.application.configure do" do
  "\n" + <<-RUBY
  config.cache_classes = !ENV['CLASS_RELOADING']
  RUBY
end
gsub_file "config/environments/test.rb", /config.enable_reloading = false/, "config.enable_reloading = !!ENV['CLASS_RELOADING']"

inject_into_file "config/environments/test.rb", after: "config.cache_classes = !ENV['CLASS_RELOADING']" do
  "\n" + <<-RUBY
  config.action_mailer.default_url_options = {host: 'example.com'}
  config.active_record.maintain_test_schema = false
  RUBY
end

gsub_file "config/boot.rb", /^.*BUNDLE_GEMFILE.*$/, <<-RUBY
  ENV['BUNDLE_GEMFILE'] = "#{File.expand_path(ENV['BUNDLE_GEMFILE'])}"
RUBY

# In https://github.com/rails/rails/pull/46699, Rails 7.1 changed sqlite directory from db/ storage/.
# Since we test we deal with rails 6.1 and 7.0, let's go back to db/
gsub_file "config/database.yml", /storage\/(.+)\.sqlite3$/, 'db/\1.sqlite3'

# Setup Active Admin
generate "active_admin:install"

gsub_file "tailwind-active_admin.config.js", /^.*const activeAdminPath.*$/, <<~JS
  const activeAdminPath = '../../../';
JS
gsub_file "tailwind-active_admin.config.js", Regexp.new("@activeadmin/activeadmin/plugin"), "../../../plugin"

# Force strong parameters to raise exceptions
inject_into_file "config/application.rb", after: "class Application < Rails::Application" do
  "\n    config.action_controller.action_on_unpermitted_parameters = :raise\n"
end

# Add some translations
append_file "config/locales/en.yml", File.read(File.expand_path("templates/en.yml", __dir__))

# Add predefined admin resources, override any file that was generated by rails new generator
directory File.expand_path("templates/admin", __dir__), "app/admin"
directory File.expand_path("templates/views", __dir__), "app/views"
directory File.expand_path("templates/policies", __dir__), "app/policies"
directory File.expand_path("templates/public", __dir__), "public", force: true

route "root to: redirect('admin')" if ENV["RAILS_ENV"] != "test"

# Rails 7.1 doesn't write test.sqlite3 files if we run db:drop, db:create and db:migrate in a single command.
# That's why we run it in two steps.
rails_command "db:drop db:create", env: ENV["RAILS_ENV"]
rails_command "db:migrate", env: ENV["RAILS_ENV"]

if ENV["RAILS_ENV"] == "test"
  inject_into_file "config/database.yml", "<%= ENV['TEST_ENV_NUMBER'] %>", after: "test.sqlite3"

  require "parallel_tests"
  ParallelTests.determine_number_of_processes(nil).times do |n|
    copy_file File.expand_path("db/test.sqlite3", destination_root), "db/test.sqlite3#{n + 1}"

    # Copy Write-Ahead-Log (-wal) and Wal-Index (-shm) files.
    # Files were introduced by rails 7.1 sqlite3 optimizations (https://github.com/rails/rails/pull/49349/files).
    %w(shm wal).each do |suffix|
      file = File.expand_path("db/test.sqlite3-#{suffix}", destination_root)
      if File.exist?(file)
        copy_file File.expand_path("db/test.sqlite3-#{suffix}", destination_root), "db/test.sqlite3#{n + 1}-#{suffix}", mode: :preserve
      end
    end
  end
end
