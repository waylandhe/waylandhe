require "yaml"
require "json"

ynab_config = if File.exist?(Rails.root.join("config", "ynab.local.yml"))
  YAML.safe_load_file(Rails.root.join("config", "ynab.local.yml"))
elsif ENV["YNAB_CONFIG"].present?
  JSON.parse(ENV["YNAB_CONFIG"])
else
  {}
end

Rails.configuration.ynab = ynab_config.deep_symbolize_keys
