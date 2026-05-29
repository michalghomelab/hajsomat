# Class-level upsert for Sequel models: insert the row, or update the non-key
# columns when a unique-index conflict occurs. `update:` overrides which columns
# get written on conflict (defaults to everything except the conflict target).
module Upsertable
  def upsert(values, conflict_target:, update: nil)
    update ||= values.except(*Array(conflict_target))
    dataset.insert_conflict(target: conflict_target, update: update).insert(values)
  end
end
