require 'tempfile'

class ImportsController < RageController::API
  def create
    portfolio = Portfolio[params[:id].to_i]
    return render json: { error: 'not found' }, status: :not_found unless portfolio

    file = Tempfile.new(['xtb', '.xlsx'])
    file.binmode
    file.write(request.env['rack.input'].tap(&:rewind).read)
    file.flush
    render json: XtbReportImporter.call(portfolio_id: portfolio.id, path: file.path)
  rescue StandardError => e
    Rage.logger.warn("XTB import failed: #{e.message}")
    render json: { error: 'Nie udało się wczytać raportu XTB' }, status: 422
  ensure
    file&.close
    file&.unlink
  end
end
