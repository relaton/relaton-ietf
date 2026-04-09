require "webmock/rspec"
require "zip"
require "yaml"

RFC_INDEX_ZIP_PATH = File.join(__dir__, "..", "fixtures", "rfc-index-v1.zip")
RSS_INDEX_ZIP_PATH = File.join(__dir__, "..", "fixtures", "rss-index-v1.zip")
IDS_INDEX_ZIP_PATH = File.join(__dir__, "..", "fixtures", "ids-index-v1.zip")

RSpec.configure do |config|
  config.before(:suite) do
    { RFC: RFC_INDEX_ZIP_PATH, RSS: RSS_INDEX_ZIP_PATH, IDS: IDS_INDEX_ZIP_PATH }.each do |sym, path|
      yaml = Zip::File.open(path) do |zip|
        zip.first.get_input_stream.read
      end
      index_data = YAML.safe_load(yaml, permitted_classes: [Symbol])

      type = Relaton::Index::Type.new(sym, nil, "index-v1.yaml")
      type.instance_variable_set(:@index, index_data)
      type.define_singleton_method(:actual?) { |**args| args.key?(:url) }

      Relaton::Index.pool.instance_variable_get(:@pool)[sym] = type
    end
  end

  config.before(:each) do
    WebMock.reset!
    WebMock.disable_net_connect!
  end
end
