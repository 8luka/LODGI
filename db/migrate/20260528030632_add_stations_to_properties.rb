class AddStationsToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :stations, :string, array: true, default: []
  end
end
