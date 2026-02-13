class YnabClient
  def initialize
    @api = YNAB::API.new(ENV.fetch("YNAB_ACCESS_TOKEN"))
    @budget_id = ENV["YNAB_BUDGET_ID"].presence ||
                 Rails.configuration.ynab.fetch(:budget_id, "last-used")
  end

  def budgets
    response = @api.budgets.get_budgets
    response.data.budgets
  end

  def accounts
    response = @api.accounts.get_accounts(@budget_id)
    response.data.accounts.reject { |a| a.closed || a.deleted }
  end

  def categories
    response = @api.categories.get_categories(@budget_id)
    response.data.category_groups.flat_map(&:categories).reject { |c| c.hidden || c.deleted }
  end
end
