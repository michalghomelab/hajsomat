class ApplicationController < RageController::API
  private

  # Renders a service's Dry::Monads::Result so controllers stay logic-free:
  # Success(data) -> JSON with `ok` status (or 204 when data is nil);
  # Failure([status, body]) -> that status with body as JSON.
  def render_result(result, status: :ok)
    if result.success?
      data = result.value!
      data.nil? ? head(:no_content) : render(json: data, status: status)
    else
      code, body = result.failure
      render json: body, status: code
    end
  end
end
