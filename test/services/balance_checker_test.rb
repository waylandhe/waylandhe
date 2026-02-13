require "test_helper"

class BalanceCheckerTest < ActiveSupport::TestCase
  test "no alerts when all balances above minimum" do
    accounts = [
      stub_account(name: "Checking", balance: 2_000_000),
      stub_account(name: "Savings", balance: 6_000_000)
    ]

    results = BalanceChecker.check(
      accounts: accounts,
      minimum_balances: { "Checking" => 1000, "Savings" => 5000 }
    )

    assert_empty results
  end

  test "alerts when balance is below minimum" do
    accounts = [
      stub_account(name: "Checking", balance: 800_000)
    ]

    results = BalanceChecker.check(
      accounts: accounts,
      minimum_balances: { "Checking" => 1000 }
    )

    assert_equal 1, results.size
    lb = results.first
    assert_equal "Checking", lb.account_name
    assert_equal 800_000, lb.balance
    assert_equal 1_000_000, lb.minimum
  end

  test "no alert when balance exactly equals minimum" do
    accounts = [
      stub_account(name: "Checking", balance: 1_000_000)
    ]

    results = BalanceChecker.check(
      accounts: accounts,
      minimum_balances: { "Checking" => 1000 }
    )

    assert_empty results
  end

  test "skips accounts not in minimum_balances" do
    accounts = [
      stub_account(name: "Checking", balance: 500_000),
      stub_account(name: "Savings", balance: 100_000)
    ]

    results = BalanceChecker.check(
      accounts: accounts,
      minimum_balances: { "Checking" => 1000 }
    )

    assert_equal 1, results.size
    assert_equal "Checking", results.first.account_name
  end

  test "skips minimum_balances for unknown accounts" do
    accounts = [
      stub_account(name: "Checking", balance: 2_000_000)
    ]

    results = BalanceChecker.check(
      accounts: accounts,
      minimum_balances: { "Nonexistent Account" => 1000 }
    )

    assert_empty results
  end

  test "multiple accounts below minimum" do
    accounts = [
      stub_account(name: "Checking", balance: 500_000),
      stub_account(name: "Savings", balance: 2_000_000)
    ]

    results = BalanceChecker.check(
      accounts: accounts,
      minimum_balances: { "Checking" => 1000, "Savings" => 5000 }
    )

    assert_equal 2, results.size
    names = results.map(&:account_name)
    assert_includes names, "Checking"
    assert_includes names, "Savings"
  end

  private

  def stub_account(name:, balance:)
    OpenStruct.new(name: name, balance: balance)
  end
end
