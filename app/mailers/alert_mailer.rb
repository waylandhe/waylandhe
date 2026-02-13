class AlertMailer < ApplicationMailer
  helper AlertMailerHelper

  def alert(shortfalls:, low_balances:)
    @shortfalls = shortfalls
    @low_balances = low_balances

    mail(
      to: ENV.fetch("ALERT_EMAIL_TO"),
      from: ENV.fetch("ALERT_EMAIL_FROM"),
      subject: "YNAB Alert: #{alert_subject_summary}"
    )
  end

  private

  def alert_subject_summary
    parts = []
    parts << "#{@shortfalls.size} CC shortfall#{"s" if @shortfalls.size != 1}" if @shortfalls.any?
    parts << "#{@low_balances.size} low balance#{"s" if @low_balances.size != 1}" if @low_balances.any?
    parts.join(", ")
  end
end
