class Transaction < Sequel::Model
  many_to_one :portfolio
  many_to_one :instrument

  def validate
    super
    errors.add(:quantity, "must be > 0") if quantity.nil? || quantity <= 0
    errors.add(:price, "must be >= 0") if price.nil? || price < 0
    errors.add(:kind, "must be buy or sell") unless %w[buy sell].include?(kind)
    errors.add(:executed_at, "cannot be in the future") if executed_at && executed_at > Time.now
  end
end
