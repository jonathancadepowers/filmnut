namespace :scheduled_tasks do
  desc "Retrieves, summarizes, and persits recently played Spotify tracks."
  task get_spotify_tracks: :environment do

    # final_artists_and_tracks => Unfiltered list of all Spotify activity.
    # final_artists_and_tracks_filtered => Subset of final_artists_and_tracks, containing only artists with more than three tracks.
    # The filtered Hash contains only track counts for each artist, not the track names.

    filmnut_user = User.find {|u| u.email == "jpowers@gmail.com"}
    spotify_user = RSpotify::User.new(filmnut_user.spotify_user)
    one_hour_ago = (Time.zone.now - 1.hours).to_datetime.strftime("%Q")    
    recent_spotify_activity = spotify_user.recently_played(limit: 50, after: one_hour_ago)    
    
    if recent_spotify_activity.count.positive?

      # Build a hash containing only the NEW artists and tracks.
      new_artists_and_tracks = recent_spotify_activity.each_with_object({}) do |track, new_artists_and_tracks|
        track.artists.each do |artist|
          if new_artists_and_tracks.key?(artist.name)
            new_artists_and_tracks[artist.name] << track.name
          else
            new_array = [track.name]
            new_artists_and_tracks[artist.name] = new_array            
          end
        end
      end      

      # Get today's TunesSummary object, if it exists.
      local_time_zone = ApplicationController.helpers.app_time_zone_as_zone
      today_year_local = DateTime.now.in_time_zone(local_time_zone).strftime("%Y").to_i
      today_month_local = DateTime.now.in_time_zone(local_time_zone).strftime("%m").to_i
      today_day_local = DateTime.now.in_time_zone(local_time_zone).strftime("%d").to_i
      today_start_utc = DateTime.new(today_year_local,today_month_local,today_day_local,0,0,0).in_time_zone(Time.zone)
      today_midday_utc = DateTime.new(today_year_local,today_month_local,today_day_local,12,0,0).in_time_zone(Time.zone)
      today_end_utc = DateTime.new(today_year_local,today_month_local,today_day_local,23,59,59).in_time_zone(Time.zone)
      tunes_summary = TunesSummary.where(summary_date: today_start_utc..today_end_utc).first

      # Create an updated list of unfiltered artists and tracks by
      # merging together new and existing data.
      final_artists_and_tracks = if tunes_summary.nil?
        new_artists_and_tracks       
      else
        tunes_summary.artists_and_tracks.deeper_merge(new_artists_and_tracks)
      end

      # Create a new hash that contains only artists with more than three tracks.
      final_artists_and_tracks_filtered = final_artists_and_tracks.each_with_object({}) do |at, final_artists_and_tracks_filtered|
        if at[1].count >= 3
          final_artists_and_tracks_filtered[at[0]] = at[1].count          
        end
      end

      # Persist outputs to the database.
      if tunes_summary.nil?
        tunes_summary = TunesSummary.new
        tunes_summary.summary_date = today_midday_utc
        tunes_summary.artists_and_tracks = final_artists_and_tracks
        tunes_summary.artists_and_tracks_filtered = final_artists_and_tracks_filtered
        # Only create a new LifeLog if final_artists_and_tracks_filtered is not null.
        if final_artists_and_tracks_filtered.empty? == false
          tunes_summary.create_life_log(
            display_timestamp: today_midday_utc,
            related_object_type: "tunes_summary"
          )
        end  
        tunes_summary.save        
      else
        tunes_summary.update(artists_and_tracks: final_artists_and_tracks, artists_and_tracks_filtered: final_artists_and_tracks_filtered)
        # Only create a new LifeLog if (a) it doesn't already exist, and (b) final_artists_and_tracks_filtered is not null.
        if tunes_summary.life_log_id.nil? == true && final_artists_and_tracks_filtered.nil? == false
          tunes_summary.create_life_log(
            display_timestamp: today_midday_utc,
            related_object_type: "tunes_summary"
          )
        end
      end
    end
  end
end
