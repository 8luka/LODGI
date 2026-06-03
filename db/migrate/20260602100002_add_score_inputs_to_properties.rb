class AddScoreInputsToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :score_inputs, :jsonb, default: {}, null: false
  end
end
