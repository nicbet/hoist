require 'base64'
# Definition of additonal filters for Liquid templates

module Hoist::AdditionalFilters
  def base64enc(input)
    Base64.encode64(input)
  end

  def base64dec(input)
    Base64.decode64(input)
  end
end
