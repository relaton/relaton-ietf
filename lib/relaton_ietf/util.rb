module RelatonIetf
  module Util
    extend RelatonBib::Util

    def self.logger
      RelatonIetf.configuration.logger
    end
  end
end
