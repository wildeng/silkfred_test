class ChangeColumnNameToCsvuploads < ActiveRecord::Migration
  def change
    rename_column :csvuploads, :original_file, :originalfile
  end
end
