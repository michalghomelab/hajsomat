# App-wide key/value settings, shared across the web and scheduler processes.
class Setting < Sequel::Model
  def self.get(key, default = nil)
    row = self[key]
    row ? row.value : default
  end

  def self.put(key, value)
    dataset.insert_conflict(target: :key, update: { value: value }).insert(key: key, value: value)
  end
end
