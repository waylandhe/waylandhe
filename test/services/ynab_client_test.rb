require "test_helper"

class YnabClientTest < ActiveSupport::TestCase
  setup do
    skip "YNAB_ACCESS_TOKEN not set — run `rake ynab:setup`" unless ENV["YNAB_ACCESS_TOKEN"].present?
  end

  test "budgets returns at least one budget" do
    client = YnabClient.new
    budgets = client.budgets

    assert_kind_of Array, budgets
    assert budgets.any?, "Expected at least one budget. Check your YNAB access token."

    budgets.each do |budget|
      assert_respond_to budget, :id
      assert_respond_to budget, :name
    end
  end

  test "accounts returns a non-empty array of open accounts" do
    client = YnabClient.new

    begin
      accounts = client.accounts
    rescue YNAB::ApiError => e
      if e.code == 404
        budgets = client.budgets
        budget_names = budgets.map { |b| "#{b.name} (#{b.id})" }.join(", ")
        flunk "Budget not found (404). budget_id=#{client_budget_id}. " \
              "Available budgets: #{budget_names}. Run `rake ynab:setup` to fix."
      else
        flunk "YNAB API error: code=#{e.code}, body=#{e.response_body}"
      end
    end

    assert_kind_of Array, accounts
    assert accounts.any?, "Expected at least one account, got none"

    accounts.each do |account|
      assert_respond_to account, :id
      assert_respond_to account, :name
      assert_respond_to account, :type
      assert_respond_to account, :balance
      refute account.closed, "Expected only open accounts, but #{account.name} is closed"
      refute account.deleted, "Expected only non-deleted accounts, but #{account.name} is deleted"
    end
  end

  test "categories returns a non-empty array" do
    client = YnabClient.new

    begin
      categories = client.categories
    rescue YNAB::ApiError => e
      flunk "YNAB API error: code=#{e.code}, body=#{e.response_body}"
    end

    assert_kind_of Array, categories
    assert categories.any?, "Expected at least one category, got none"

    categories.each do |category|
      assert_respond_to category, :id
      assert_respond_to category, :name
      assert_respond_to category, :balance
    end
  end

  private

  def client_budget_id
    ENV.fetch("YNAB_BUDGET_ID", nil) ||
      Rails.configuration.ynab.fetch(:budget_id, "last-used")
  end
end
