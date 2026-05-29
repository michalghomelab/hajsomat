# App-wide key/value settings, shared across the web and scheduler processes.
class Setting < Sequel::Model
  extend Upsertable

  def self.get(key, default = nil)
    row = self[key]
    row ? row.value : default
  end

  def self.put(key, value)
    upsert({ key: key, value: value }, conflict_target: :key)
  end
end
