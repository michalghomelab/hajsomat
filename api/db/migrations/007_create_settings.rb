Sequel.migration do
  change do
    create_table(:settings) do
      String :key, primary_key: true
      String :value, null: false
    end
  end
end
