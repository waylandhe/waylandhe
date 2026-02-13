require "test_helper"

class CoverageCheckerTest < ActiveSupport::TestCase
  setup do
    @checking = stub_account(id: "chk-1", name: "Primary Checking", balance: 5_000_000, type: "checking")
    @cc = stub_account(id: "cc-1", name: "Chase Sapphire", balance: -2_000_000, type: "creditCard")
    @cc_category = stub_category(name: "Chase Sapphire", balance: 2_000_000, category_group_name: "Credit Card Payments")
    @mappings = { "Chase Sapphire" => "chk-1" }
  end

  test "no shortfall when checking can cover payment" do
    shortfalls = CoverageChecker.check(
      accounts: [@checking, @cc],
      categories: [@cc_category],
      account_mappings: @mappings
    )

    assert_empty shortfalls
  end

  test "uncoverable when checking balance minus minimum is less than payment" do
    checking = stub_account(id: "chk-1", name: "Primary Checking", balance: 1_500_000, type: "checking")

    shortfalls = CoverageChecker.check(
      accounts: [checking, @cc],
      categories: [@cc_category],
      account_mappings: @mappings,
      minimum_balances: { "Primary Checking" => 1000 }
    )

    assert_equal 1, shortfalls.size
    s = shortfalls.first
    assert_equal "Chase Sapphire", s.cc_name
    assert_equal 2_000_000, s.payment_needed
    assert_equal "Primary Checking", s.checking_name
    assert_equal 500_000, s.available_checking
    assert s.uncoverable
  end

  test "no shortfall when only underfunded but checking can cover" do
    cc_category = stub_category(name: "Chase Sapphire", balance: 0, category_group_name: "Credit Card Payments")

    shortfalls = CoverageChecker.check(
      accounts: [@checking, @cc],
      categories: [cc_category],
      account_mappings: @mappings
    )

    assert_empty shortfalls
  end

  test "minimum balance reduces available checking" do
    checking = stub_account(id: "chk-1", name: "Primary Checking", balance: 3_000_000, type: "checking")

    shortfalls = CoverageChecker.check(
      accounts: [checking, @cc],
      categories: [@cc_category],
      account_mappings: @mappings,
      minimum_balances: { "Primary Checking" => 2000 }
    )

    assert_equal 1, shortfalls.size
    s = shortfalls.first
    assert_equal 1_000_000, s.available_checking
    assert s.uncoverable
  end

  test "skips unknown credit card names" do
    shortfalls = CoverageChecker.check(
      accounts: [@checking, @cc],
      categories: [@cc_category],
      account_mappings: { "Unknown Card" => "chk-1" }
    )

    assert_empty shortfalls
  end

  test "skips unknown checking account ids" do
    shortfalls = CoverageChecker.check(
      accounts: [@checking, @cc],
      categories: [@cc_category],
      account_mappings: { "Chase Sapphire" => "nonexistent-id" }
    )

    assert_empty shortfalls
  end

  test "handles missing payment category" do
    checking = stub_account(id: "chk-1", name: "Primary Checking", balance: 1_000_000, type: "checking")

    shortfalls = CoverageChecker.check(
      accounts: [checking, @cc],
      categories: [],
      account_mappings: @mappings
    )

    assert_equal 1, shortfalls.size
    assert_equal 0, shortfalls.first.payment_available
    assert shortfalls.first.uncoverable
  end

  test "multiple credit cards mapped to different checking accounts" do
    checking_a = stub_account(id: "chk-a", name: "Checking A", balance: 500_000, type: "checking")
    checking_b = stub_account(id: "chk-b", name: "Checking B", balance: 10_000_000, type: "checking")
    cc_a = stub_account(id: "cc-a", name: "Card A", balance: -1_000_000, type: "creditCard")
    cc_b = stub_account(id: "cc-b", name: "Card B", balance: -3_000_000, type: "creditCard")

    shortfalls = CoverageChecker.check(
      accounts: [checking_a, checking_b, cc_a, cc_b],
      categories: [],
      account_mappings: { "Card A" => "chk-a", "Card B" => "chk-b" }
    )

    assert_equal 1, shortfalls.size
    assert_equal "Card A", shortfalls.first.cc_name
  end

  private

  def stub_account(id:, name:, balance:, type:)
    OpenStruct.new(id: id, name: name, balance: balance, type: type, closed: false, deleted: false)
  end

  def stub_category(name:, balance:, category_group_name:)
    OpenStruct.new(name: name, balance: balance, category_group_name: category_group_name, hidden: false, deleted: false)
  end
end
