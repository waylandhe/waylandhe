require "test_helper"

class AlertMailerTest < ActionMailer::TestCase
  setup do
    ENV["ALERT_EMAIL_TO"] = "test@example.com"
    ENV["ALERT_EMAIL_FROM"] = "alerts@example.com"
  end

  test "alert with shortfalls and low balances" do
    email = AlertMailer.alert(shortfalls: [sample_shortfall], low_balances: [sample_low_balance])

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["test@example.com"], email.to
    assert_equal ["alerts@example.com"], email.from
    assert_equal "YNAB Alert: 1 CC shortfall, 1 low balance", email.subject

    text = email.text_part.body.to_s
    assert_includes text, "Chase Sapphire"
    assert_includes text, "Savings"

    html = email.html_part.body.to_s
    assert_includes html, "Chase Sapphire"
    assert_includes html, "Savings"
  end

  test "alert with only shortfalls" do
    email = AlertMailer.alert(shortfalls: [sample_shortfall], low_balances: [])

    assert_equal "YNAB Alert: 1 CC shortfall", email.subject

    text = email.text_part.body.to_s
    assert_includes text, "Chase Sapphire"
    assert_includes text, "$2000.00"
  end

  test "alert with only low balances" do
    low_balances = [
      sample_low_balance,
      BalanceChecker::LowBalance.new(
        account_name: "Checking",
        balance: 500_000,
        minimum: 1_000_000
      )
    ]

    email = AlertMailer.alert(shortfalls: [], low_balances: low_balances)

    assert_equal "YNAB Alert: 2 low balances", email.subject

    text = email.text_part.body.to_s
    assert_includes text, "Savings"
    assert_includes text, "Checking"
  end

  test "subject pluralizes correctly" do
    shortfalls = [
      sample_shortfall,
      CoverageChecker::Shortfall.new(
        cc_name: "Amex Gold",
        payment_needed: 300_000,
        payment_available: 0,
        checking_name: "Checking",
        checking_balance: 100_000,
        checking_minimum: 0,
        available_checking: 100_000,
        underfunded: true,
        uncoverable: true
      )
    ]

    email = AlertMailer.alert(shortfalls: shortfalls, low_balances: [])

    assert_equal "YNAB Alert: 2 CC shortfalls", email.subject
  end

  private

  def sample_shortfall
    CoverageChecker::Shortfall.new(
      cc_name: "Chase Sapphire",
      payment_needed: 2_000_000,
      payment_available: 100_000,
      checking_name: "Primary Checking",
      checking_balance: 1_500_000,
      checking_minimum: 1_000_000,
      available_checking: 500_000,
      underfunded: true,
      uncoverable: true
    )
  end

  def sample_low_balance
    BalanceChecker::LowBalance.new(
      account_name: "Savings",
      balance: 3_000_000,
      minimum: 5_000_000
    )
  end
end
