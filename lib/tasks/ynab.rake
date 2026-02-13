namespace :ynab do
  desc "Check credit card coverage and minimum balances, send alert email if issues found"
  task check: :environment do
    config = Rails.configuration.ynab
    client = YnabClient.new
    accounts = client.accounts
    categories = client.categories

    account_mappings = config.fetch(:account_mappings, {}).transform_keys(&:to_s)
    minimum_balances = config.fetch(:minimum_balances, {}).transform_keys(&:to_s)

    shortfalls = CoverageChecker.check(
      accounts: accounts,
      categories: categories,
      account_mappings: account_mappings,
      minimum_balances: minimum_balances
    )

    low_balances = BalanceChecker.check(
      accounts: accounts,
      minimum_balances: minimum_balances
    )

    if shortfalls.empty? && low_balances.empty?
      puts "All clear — no issues found."
      next
    end

    puts "Found #{shortfalls.size} CC shortfall(s), #{low_balances.size} low balance(s)."
    puts

    shortfalls.each do |s|
      puts "CC: #{s.cc_name}"
      puts "  Payment needed:    #{format_milliunits(s.payment_needed)}"
      puts "  Payment available: #{format_milliunits(s.payment_available)}"
      puts "  Checking:          #{s.checking_name} (#{format_milliunits(s.checking_balance)}, min: #{format_milliunits(s.checking_minimum)})"
      puts "  Available to pay:  #{format_milliunits(s.available_checking)}"
      puts "  Underfunded: #{s.underfunded}" if s.underfunded
      puts "  Uncoverable: #{s.uncoverable}" if s.uncoverable
      puts
    end

    low_balances.each do |lb|
      puts "Low balance: #{lb.account_name}"
      puts "  Balance:  #{format_milliunits(lb.balance)}"
      puts "  Minimum:  #{format_milliunits(lb.minimum)}"
      puts
    end

    if ENV["DRY_RUN"].present?
      puts "DRY_RUN enabled — skipping email."
    else
      AlertMailer.alert(shortfalls: shortfalls, low_balances: low_balances).deliver_now
      puts "Alert email sent."
    end
  end

  desc "List all YNAB accounts with IDs, types, and balances"
  task list_accounts: :environment do
    client = YnabClient.new
    accounts = client.accounts

    puts "%-40s %-10s %-36s %s" % ["Name", "Type", "ID", "Balance"]
    puts "-" * 100

    accounts.sort_by(&:name).each do |account|
      puts "%-40s %-10s %-36s %s" % [
        account.name,
        account.type,
        account.id,
        format_milliunits(account.balance)
      ]
    end
  end

  desc "Interactive setup: create .env and config/ynab.local.yml"
  task setup: :environment do
    env_path = Rails.root.join(".env")
    yaml_path = Rails.root.join("config", "ynab.local.yml")
    existing_yaml = if yaml_path.exist?
      YAML.safe_load_file(yaml_path).deep_symbolize_keys
    else
      {}
    end

    # Step 1: Get or prompt for access token
    token = ENV["YNAB_ACCESS_TOKEN"].presence
    if token
      puts "Using YNAB_ACCESS_TOKEN from environment."
    else
      print "Enter your YNAB personal access token: "
      token = prompt.strip
      abort "No token provided." if token.empty?
    end

    # Step 2: Fetch budgets
    api = YNAB::API.new(token)
    budgets = api.budgets.get_budgets.data.budgets

    if budgets.empty?
      abort "No budgets found for this token. Check your YNAB account."
    end

    existing_budget_id = existing_yaml[:budget_id]
    existing_budget = budgets.find { |b| b.id == existing_budget_id } if existing_budget_id

    budget = if existing_budget
      puts "\nCurrent budget: #{existing_budget.name} (#{existing_budget.id})"
      print "Keep this budget? (y/n): "
      if prompt.strip.downcase == "y"
        existing_budget
      else
        select_budget(budgets)
      end
    else
      select_budget(budgets)
    end

    # Step 3: Fetch accounts for the selected budget
    accounts = api.accounts.get_accounts(budget.id).data.accounts.reject { |a| a.closed || a.deleted }
    credit_cards = accounts.select { |a| a.type == "creditCard" }.sort_by(&:name)
    checking_accounts = accounts.select { |a| a.type == "checking" }.sort_by(&:name)

    puts "\nAccounts in '#{budget.name}':"
    puts "%-4s %-40s %-12s %s" % ["#", "Name", "Type", "Balance"]
    puts "-" * 70
    accounts.sort_by(&:name).each_with_index do |a, i|
      dollars = a.balance / 1000.0
      puts "%-4s %-40s %-12s $%.2f" % [i + 1, a.name, a.type, dollars]
    end

    # Step 4: Map credit cards to checking accounts
    existing_mappings = existing_yaml.fetch(:account_mappings, {}).transform_keys(&:to_s)
    account_mappings = {}

    if credit_cards.any? && checking_accounts.any?
      if existing_mappings.any?
        puts "\n--- Credit Card Mappings ---"
        puts "Current mappings:"
        existing_mappings.each do |cc_name, checking_id|
          checking = accounts.find { |a| a.id == checking_id }
          puts "  #{cc_name} -> #{checking&.name || checking_id}"
        end
        print "\nKeep existing mappings? (y/n): "
        if prompt.strip.downcase == "y"
          account_mappings = existing_mappings
        else
          account_mappings = prompt_account_mappings(credit_cards, checking_accounts)
        end
      else
        account_mappings = prompt_account_mappings(credit_cards, checking_accounts)
      end
    end

    # Step 5: Set minimum balances
    existing_minimums = existing_yaml.fetch(:minimum_balances, {}).transform_keys(&:to_s)
    minimum_balances = {}
    trackable = accounts.select { |a| %w[checking savings].include?(a.type) }.sort_by(&:name)

    if trackable.any?
      if existing_minimums.any?
        puts "\n--- Minimum Balance Alerts ---"
        puts "Current minimums:"
        existing_minimums.each do |name, min|
          puts "  #{name} -> $#{min}"
        end
        print "\nKeep existing minimums? (y/n): "
        if prompt.strip.downcase == "y"
          minimum_balances = existing_minimums
        else
          minimum_balances = prompt_minimum_balances(trackable)
        end
      else
        minimum_balances = prompt_minimum_balances(trackable)
      end
    end

    # Step 6: Email alert settings
    env_vars = { "YNAB_ACCESS_TOKEN" => token }
    existing_smtp = ENV["SMTP_ADDRESS"].present? && ENV["SMTP_PASSWORD"].present?

    if existing_smtp
      puts "\n--- Email Alerts ---"
      puts "Current config: #{ENV["SMTP_USERNAME"]} via #{ENV["SMTP_ADDRESS"]}"
      puts "  Sending to: #{ENV["ALERT_EMAIL_TO"]}"
      print "Keep existing email settings? (y/n): "
      if prompt.strip.downcase == "y"
        env_vars.merge!(
          "SMTP_ADDRESS" => ENV["SMTP_ADDRESS"],
          "SMTP_PORT" => ENV.fetch("SMTP_PORT", "587"),
          "SMTP_USERNAME" => ENV["SMTP_USERNAME"],
          "SMTP_PASSWORD" => ENV["SMTP_PASSWORD"],
          "ALERT_EMAIL_TO" => ENV["ALERT_EMAIL_TO"],
          "ALERT_EMAIL_FROM" => ENV["ALERT_EMAIL_FROM"]
        )
      else
        prompt_email_settings(env_vars)
      end
    else
      prompt_email_settings(env_vars)
    end

    # Step 7: Write .env
    env_contents = env_vars.map { |k, v| "#{k}=#{v}" }.join("\n") + "\n"
    File.write(env_path, env_contents)
    puts "\nWrote #{env_path}"

    # Step 8: Write ynab.local.yml
    yaml_config = { "budget_id" => budget.id }
    yaml_config["account_mappings"] = account_mappings if account_mappings.any?
    yaml_config["minimum_balances"] = minimum_balances if minimum_balances.any?

    File.write(yaml_path, yaml_config.to_yaml)
    puts "Wrote #{yaml_path}"

    puts "\nSetup complete! Run `rake ynab:list_accounts` to verify."
  end

  desc "Export local YAML config as JSON for YNAB_CONFIG env var"
  task export_config: :environment do
    yaml_path = Rails.root.join("config", "ynab.local.yml")

    unless File.exist?(yaml_path)
      abort "Error: config/ynab.local.yml not found. Copy config/ynab.yml.example and fill it in."
    end

    config = YAML.safe_load_file(yaml_path)
    puts config.to_json
  end

  def prompt
    input = $stdin.gets
    abort "\nAborted." if input.nil?
    input.chomp
  end

  def select_budget(budgets)
    puts "\nAvailable budgets:"
    budgets.each_with_index do |b, i|
      puts "  #{i + 1}) #{b.name} (#{b.id})"
    end

    if budgets.size == 1
      puts "\nAuto-selecting the only budget: #{budgets.first.name}"
      budgets.first
    else
      print "\nSelect a budget (1-#{budgets.size}): "
      choice = prompt.to_i
      abort "Invalid selection." unless choice.between?(1, budgets.size)
      budgets[choice - 1]
    end
  end

  def prompt_account_mappings(credit_cards, checking_accounts)
    mappings = {}
    puts "\n--- Credit Card Mappings ---"
    puts "For each credit card, pick which checking account pays it."
    puts "Checking accounts:"
    checking_accounts.each_with_index do |a, i|
      puts "  #{i + 1}) #{a.name} (#{a.id})"
    end

    credit_cards.each do |cc|
      print "\nWhich checking account pays '#{cc.name}'? (1-#{checking_accounts.size}, or s to skip): "
      input = prompt.strip.downcase
      next if input == "s" || input.empty?

      idx = input.to_i
      next unless idx.between?(1, checking_accounts.size)

      mappings[cc.name] = checking_accounts[idx - 1].id
      puts "  #{cc.name} -> #{checking_accounts[idx - 1].name}"
    end
    mappings
  end

  def prompt_minimum_balances(trackable)
    minimums = {}
    puts "\n--- Minimum Balance Alerts ---"
    puts "Set a minimum balance (in dollars) for each account, or s to skip."

    trackable.each do |a|
      dollars = a.balance / 1000.0
      print "Minimum for '#{a.name}' (current: $#{"%.2f" % dollars})? "
      input = prompt.strip.downcase
      next if input == "s" || input.empty?

      min = input.to_i
      if min > 0
        minimums[a.name] = min
        puts "  #{a.name} -> $#{min}"
      end
    end
    minimums
  end

  def prompt_email_settings(env_vars)
    puts "\n--- Email Alerts (Gmail SMTP) ---"
    puts "To send alert emails, you need a Gmail App Password."
    puts "Get one at: https://myaccount.google.com/apppasswords"

    print "\nSet up email alerts now? (y/n): "
    unless prompt.strip.downcase == "y"
      puts "Skipping email setup. You can re-run `rake ynab:setup` later."
      return
    end

    print "Gmail address: "
    gmail = prompt.strip
    abort "No email provided." if gmail.empty?

    print "Gmail App Password (16 chars): "
    app_password = prompt.strip
    abort "No password provided." if app_password.empty?

    print "Send alerts to (default: #{gmail}): "
    alert_to = prompt.strip
    alert_to = gmail if alert_to.empty?

    env_vars.merge!(
      "SMTP_ADDRESS" => "smtp.gmail.com",
      "SMTP_PORT" => "587",
      "SMTP_USERNAME" => gmail,
      "SMTP_PASSWORD" => app_password,
      "ALERT_EMAIL_TO" => alert_to,
      "ALERT_EMAIL_FROM" => gmail
    )

    puts "\nSending test email to #{alert_to}..."
    begin
      ActionMailer::Base.delivery_method = :smtp
      ActionMailer::Base.smtp_settings = {
        address: "smtp.gmail.com",
        port: 587,
        user_name: gmail,
        password: app_password,
        authentication: "plain",
        enable_starttls_auto: true
      }

      ActionMailer::Base.mail(
        to: alert_to,
        from: gmail,
        subject: "YNAB Alert Setup - Test Email",
        body: "If you're reading this, email alerts are working!"
      ).deliver_now

      puts "Test email sent! Check your inbox."
    rescue => e
      puts "Failed to send test email: #{e.message}"
      puts "Your SMTP settings will still be saved — you can debug later."
    end
  end

  def format_milliunits(milliunits)
    dollars = milliunits / 1000.0
    "$#{"%.2f" % dollars}"
  end
end
