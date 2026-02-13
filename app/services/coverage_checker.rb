class CoverageChecker
  Shortfall = Struct.new(
    :cc_name, :payment_needed, :payment_available,
    :checking_name, :checking_balance, :checking_minimum,
    :available_checking, :underfunded, :uncoverable,
    keyword_init: true
  )

  # accounts: array of YNAB account objects
  # categories: array of YNAB category objects
  # account_mappings: { "CC Name" => "checking-uuid" }
  # minimum_balances: { "Checking Name" => dollars_integer }
  def self.check(accounts:, categories:, account_mappings:, minimum_balances: {})
    accounts_by_id = accounts.index_by(&:id)
    accounts_by_name = accounts.index_by(&:name)

    # YNAB auto-creates CC payment categories in "Credit Card Payments" group
    cc_payment_categories = categories.select { |c| c.category_group_name == "Credit Card Payments" }
    cc_payments_by_name = cc_payment_categories.index_by(&:name)

    shortfalls = []

    account_mappings.each do |cc_name, checking_id|
      cc_account = accounts_by_name[cc_name]
      next unless cc_account

      checking_account = accounts_by_id[checking_id]
      next unless checking_account

      payment_needed = cc_account.balance.abs
      payment_category = cc_payments_by_name[cc_name]
      payment_available = payment_category&.balance || 0

      minimum = (minimum_balances[checking_account.name] || 0) * 1000 # convert dollars to milliunits
      available_checking = checking_account.balance - minimum

      underfunded = payment_needed > payment_available
      uncoverable = payment_needed > available_checking

      next unless uncoverable

      shortfalls << Shortfall.new(
        cc_name: cc_name,
        payment_needed: payment_needed,
        payment_available: payment_available,
        checking_name: checking_account.name,
        checking_balance: checking_account.balance,
        checking_minimum: minimum,
        available_checking: available_checking,
        underfunded: underfunded,
        uncoverable: uncoverable
      )
    end

    shortfalls
  end
end
