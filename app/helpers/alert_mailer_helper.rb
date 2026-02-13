module AlertMailerHelper
  def format_milliunits(milliunits)
    dollars = milliunits / 1000.0
    "$#{"%.2f" % dollars}"
  end
end
