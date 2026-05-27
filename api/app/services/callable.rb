# Lets a service object be invoked as `Service.call(...)` instead of `Service.new(...).call`.
module Callable
  def call(...)
    new(...).call
  end
end
