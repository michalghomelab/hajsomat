class BackfillService
  # A date-indexed price/FX series that answers "value as of date" by carrying
  # the most recent prior observation forward when the exact date is missing.
  class Series
    def initialize(by_date)
      @by_date = by_date || {}
    end

    def on(date)
      @by_date[date] || @by_date.keys.select { |d| d <= date }.max&.then { |d| @by_date[d] }
    end

    def dates
      @by_date.keys
    end
  end
end
