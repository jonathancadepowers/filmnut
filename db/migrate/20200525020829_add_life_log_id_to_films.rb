class AddLifeLogIdToFilms < ActiveRecord::Migration[5.2]
  def change
    add_column :films, :life_log_id, :integer
  end
end
