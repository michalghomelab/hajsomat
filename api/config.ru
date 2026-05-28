require_relative "config/application"

map "/cable" do
  run Rage::Cable.application
end

map "/" do
  run Rage.application
end
