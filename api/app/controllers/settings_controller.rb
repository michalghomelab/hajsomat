class SettingsController < RageController::API
  def show
    render json: payload
  end

  def update
    raw = params[:refresh_interval_minutes]
    minutes = raw.to_i
    unless raw && AppSettings::ALLOWED_REFRESH_INTERVALS.include?(minutes)
      return render json: { error: 'invalid refresh_interval_minutes' }, status: 422
    end

    AppSettings.refresh_interval_minutes = minutes
    render json: payload
  end

  private

  def payload
    { refresh_interval_minutes: AppSettings.refresh_interval_minutes }
  end
end
