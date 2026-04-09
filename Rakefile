require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :spec do
  desc "Download latest IETF index fixtures from relaton-data repos"
  task :update_index do
    require "net/http"
    require "uri"

    indexes = {
      "rfc-index-v1.zip" => "https://raw.githubusercontent.com/relaton/relaton-data-rfcs/data-v2/index-v1.zip",
      "rss-index-v1.zip" => "https://raw.githubusercontent.com/relaton/relaton-data-rfcsubseries/data-v2/index-v1.zip",
      "ids-index-v1.zip" => "https://raw.githubusercontent.com/relaton/relaton-data-ids/data-v2/index-v1.zip",
    }

    indexes.each do |filename, url|
      dest = File.join(__dir__, "spec", "fixtures", filename)

      puts "Downloading #{url} ..."
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        File.binwrite(dest, response.body)
        puts "Updated #{dest} (#{response.body.bytesize} bytes)"
      else
        abort "Failed to download #{filename}: HTTP #{response.code}"
      end
    end
  end
end
