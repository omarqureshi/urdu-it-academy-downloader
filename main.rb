#!/usr/bin/env ruby

require 'net/https'
require 'uri'
require 'bundler/setup'
Bundler.require(:default)

require "active_support"
require "active_support/core_ext"

require 'json'
require 'pp'
require 'mongo'

dbc = Mongo::Client.new([ 'db:27017' ], :database => 'urdu_it_academy')
dbv = dbc[:videos]

# https://www.googleapis.com/youtube/v3/channels?id={channel Id}&key={API key}&part=contentDetails

GOOGLE_API_BASE="www.googleapis.com"
CHANNELS_BASE_PATH = "/youtube/v3/channels"
PLAYLISTS_BASE_PATH = "/youtube/v3/playlistItems"
YOUTUBE_API_KEY = ENV['YOUTUBE_API_KEY']

channel_query = {
  key: YOUTUBE_API_KEY,
  id: "UCOj01AiKoTcKZG-wOhWvr3g",
  part: "contentDetails"
}.to_query

channel_uri = URI::HTTPS.build(host: GOOGLE_API_BASE, path: CHANNELS_BASE_PATH, query: channel_query)
channel_json = JSON.parse Net::HTTP.get(channel_uri)

upload_id = channel_json["items"].first["contentDetails"]["relatedPlaylists"]["uploads"]

playlist_query_hash = {
  key: YOUTUBE_API_KEY,
  playlistId: upload_id,
  part: "snippet",
  maxResults: "50"
}

fetch = false

while (fetch)
  playlist_uri = URI::HTTPS.build(host: GOOGLE_API_BASE, path: PLAYLISTS_BASE_PATH, query: playlist_query_hash.to_query)
  playlist_json = JSON.parse Net::HTTP.get(playlist_uri)
  page_token = playlist_json["nextPageToken"]
  playlist_query_hash[:pageToken] = page_token
  fetch = !page_token.nil?

  # Implement behaviour to do download fetching
  playlist_json["items"].each do |item|
    snippet = item["snippet"]
    video_id = snippet["resourceId"]["videoId"]
    doc = {
      video_id: video_id,
      title: snippet["title"],
      description: snippet["description"]
    }
    record = dbv.find(video_id: video_id).first
    dbv.insert_one(doc) unless record

    puts video_id
    puts "-------"
    files = Dir.glob("output/#{video_id}.*")
    `yt-dlp_linux -o output/#{video_id} https://www.youtube.com/watch?v=#{video_id}` unless files.any?
    file = Dir.glob("output/#{video_id}.*").first
    puts file
    dbv.update_one( { 'video_id' => video_id }, { '$set' => { 'extension' => File.extname(file) } } ) if file
  end
end

s3 = Aws::S3::Client.new()

fetch = true
marker = nil
files = []
while (fetch)
  objects = s3.list_objects({bucket: "URDUIT", marker: marker})
  files += objects.contents.map(&:key)
  marker = objects.next_marker
  fetch = !marker.nil?
end

#pp files
#pp files.length


backup = Dir.glob("output/*").map do |f|
  File.basename(f)
#  s3.put_object({
#                  body: IO.read(f),
#                  bucket: "URDUIT",
#                  key: basename,
#                })
end

#pp backup.length

#pp files
#pp files.length

(backup - files).each do |f|
  s3.put_object({
                  body: IO.read("output/#{f}"),
                  bucket: "URDUIT",
                  key: f,
                })

end
