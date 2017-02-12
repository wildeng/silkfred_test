class CreateCsvuploads < ActiveRecord::Migration
  def change
    create_table :csvuploads do |t|
      t.string :description
      t.string :original_file
      t.string :photomontage_file
      t.timestamps null: false
    end
  end
end
