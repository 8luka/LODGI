class DropLandmarks < ActiveRecord::Migration[8.1]
  def change
    drop_table :landmarks
  end
end
