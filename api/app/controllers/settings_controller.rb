class SettingsController < ApplicationController
  def show
    render json: { refresh_interval_minutes: AppSettings.refresh_interval_minutes }
  end

  def update
    render_result(UpdateRefreshInterval.call(params[:refresh_interval_minutes]))
  end
end
