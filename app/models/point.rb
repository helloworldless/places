# point.rb

class Point

  attr_accessor :longitude, :latitude


  def to_hash
    hash = {}
    hash[:type] = "Point"
    hash[:coordinates] = []
    hash[:coordinates].push @longitude
    hash[:coordinates].push @latitude
    return hash

  end

  def initialize(hash)

    geo_coords = hash[:coordinates] unless hash[:coordinates].nil?
    @latitude = geo_coords[1] unless hash[:coordinates].nil?
    @longitude = geo_coords[0] unless hash[:coordinates].nil?

    @latitude = hash[:lat]  unless hash[:lat].nil?
    @longitude = hash[:lng]  unless hash[:lng].nil?



  end

end
