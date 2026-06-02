class AddFieldsToInquiries < ActiveRecord::Migration[8.1]
  def change
    add_column :inquiries, :commute_weight, :float
    add_column :inquiries, :quiet_weight, :float
    add_column :inquiries, :station_weight, :float
    add_column :inquiries, :selected_places, :text, array: true, default: []
  end
end
