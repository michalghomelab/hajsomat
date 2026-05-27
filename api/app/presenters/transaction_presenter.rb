class TransactionPresenter
  def self.call(transactions)
    Array(transactions).sort_by(&:executed_at).map do |t|
      {
        id: t.id,
        quantity: Decimals.string(t.quantity),
        price: Decimals.string(t.price),
        currency: t.currency,
        executed_at: t.executed_at.iso8601
      }
    end
  end
end
