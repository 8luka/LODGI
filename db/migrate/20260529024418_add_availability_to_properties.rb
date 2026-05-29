class AddAvailabilityToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :availability, :string
  end
end
