class Transaction < Sequel::Model
  many_to_one :portfolio
  many_to_one :instrument

  def self.buys_by_portfolio(portfolio_ids)
    return {} if portfolio_ids.empty?

    where(portfolio_id: portfolio_ids, kind: 'buy').all.group_by(&:portfolio_id)
  end
end
