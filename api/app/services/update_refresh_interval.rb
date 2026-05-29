require 'dry/monads'

# Sets the app-wide auto-refresh interval. Success(payload) or Failure([422, …])
# for a value outside the allowed set (auto-refresh can't be turned off).
class UpdateRefreshInterval
  extend Callable
  extend Dry::Initializer
  include Dry::Monads[:result]

  param :raw

  def call
    return Failure([422, { error: 'invalid refresh_interval_minutes' }]) unless valid?

    AppSettings.refresh_interval_minutes = raw.to_i
    Success({ refresh_interval_minutes: AppSettings.refresh_interval_minutes })
  end

  private

  def valid? = raw && AppSettings::ALLOWED_REFRESH_INTERVALS.include?(raw.to_i)
end
