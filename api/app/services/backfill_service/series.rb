class BackfillService
  # A date-indexed price/FX series that answers "value as of date" by carrying
  # the most recent prior observation forward when the exact date is missing.
  class Series
    def initialize(by_date)
      @by_date = by_date || {}
      @dates = @by_date.keys.sort
    end

    def on(date)
      return @by_date[date] if @by_date.key?(date)

      idx = (@dates.bsearch_index { |d| d > date } || @dates.size) - 1
      idx >= 0 ? @by_date[@dates[idx]] : nil
    end

    attr_reader :dates
  end
end
