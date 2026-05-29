require 'dry/monads'

# Deletes a transaction. Success(nil) -> 204, or Failure([:not_found, …]).
class DeleteTransaction
  extend Callable
  extend Dry::Initializer
  include Dry::Monads[:result]

  param :id

  def call
    txn = Transaction[id.to_i]
    return Failure([:not_found, {}]) unless txn

    txn.destroy
    Success(nil)
  end
end
