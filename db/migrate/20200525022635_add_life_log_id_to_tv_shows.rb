class AddLifeLogIdToTvShows < ActiveRecord::Migration[5.2]
  def change
    add_column :tv_shows, :life_log_id, :integer
  end
end
