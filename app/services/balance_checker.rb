class BalanceChecker
  LowBalance = Struct.new(
    :account_name, :balance, :minimum,
    keyword_init: true
  )

  # accounts: array of YNAB account objects
  # minimum_balances: { "Account Name" => dollars_integer }
  def self.check(accounts:, minimum_balances:)
    accounts_by_name = accounts.index_by(&:name)

    low_balances = []

    minimum_balances.each do |account_name, minimum_dollars|
      account = accounts_by_name[account_name]
      next unless account

      minimum_milliunits = minimum_dollars * 1000

      next unless account.balance < minimum_milliunits

      low_balances << LowBalance.new(
        account_name: account_name,
        balance: account.balance,
        minimum: minimum_milliunits
      )
    end

    low_balances
  end
end
