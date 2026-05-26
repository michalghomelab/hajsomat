class Transaction < Sequel::Model
  many_to_one :portfolio
  many_to_one :instrument

  def validate
    super
    validate_quantity
    validate_price
    validate_kind
    validate_executed_at
  end

  private

  def validate_quantity
    errors.add(:quantity, 'must be > 0') if quantity.nil? || quantity <= 0
  end

  def validate_price
    errors.add(:price, 'must be >= 0') if price.nil? || price.negative?
  end

  def validate_kind
    errors.add(:kind, 'must be buy or sell') unless %w[buy sell].include?(kind)
  end

  def validate_executed_at
    errors.add(:executed_at, 'cannot be in the future') if executed_at && executed_at > Time.now
  end
end
