
class Photo #< ActiveRecord::Base
  #belongs_to :place

  include ActiveModel::Model

  attr_accessor :id, :location, :contents
  #attr_writer :contents

	def self.mongo_client
    Mongoid::Clients.default
  end

  def initialize(hash=nil)
    if hash
      @id = hash[:_id].to_s
      #byebug
      @location = Point.new(hash[:metadata][:location])
      @place = hash[:metadata][:place] unless hash[:metadata][:place].nil?
    else
     @id = nil
     @location = nil
     @place = nil
    end
  end

  def place
    if @place
      #byebug
      Place.find(@place)#.id
    else 
      nil
    end
  end

  def place=(value)
    if value.nil? || value == ''
      @place = nil
    elsif value.class == BSON::ObjectId
      @place = value
    elsif value.class == Place
      @place = BSON::ObjectId.from_string(value.id)
    elsif value.class == String #and !value==''
      @place = BSON::ObjectId.from_string(value)
    # elsif value.nil? || value==''
    #   @place = nil
    end
  end

  def persisted?
    !@id.nil?
  end

  def save

    description = {}
    #description[:filename] = @filename
    description[:content_type] = 'image/jpeg'
    description[:metadata] = {}
    #description[:metadata][:location] = @location.to_hash
    description[:metadata][:place] = @place#.to_s

    if !self.persisted?

      @contents.rewind

      gps = EXIFR::JPEG.new(@contents).gps

      @location = Point.new(:lng=>gps.longitude, :lat=>gps.latitude)
      description[:metadata][:location] = @location.to_hash

      @contents.rewind

      grid_file = Mongo::Grid::File.new(@contents.read, description)
      id = self.class.mongo_client.database.fs.insert_one(grid_file)
      @id = id.to_s
    else
      description[:metadata][:location] = @location.to_hash
      description[:metadata][:place] = @place#.to_s
      #byebug
      self.class.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id)).update_one(:$set=>{:metadata=>description[:metadata]})
    end
  end

  def self.all(skip=0, limit=0)
    # was inexplicably Place.mongo_client.database.fs.find.skip(skip)
    result = Photo.mongo_client.database.fs.find.skip(skip)
    result = result.limit(limit) unless limit==0
    result = result.to_a
    result.map {|doc| Photo.new(doc) }
  end

  def self.find id
    # was inexplicably Place.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(id)).first
    doc = Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(id)).first
    #byebug
    if doc
      # could be refactor to pass the doc to initialization
      photo = Photo.new
      photo.id = doc[:_id].to_s
      photo.place = doc[:metadata][:place]
      photo.location = Point.new(doc[:metadata][:location])
      #byebug
      return photo
    else 
      nil
      #raise 'Photo.find(id) did not find any results!'
    end
  end

  # custom getter for :contents
  def contents
    f = Place.mongo_client.database.fs.find_one(:_id=>BSON::ObjectId.from_string(@id))
    if f
      buffer = ""
      f.chunks.reduce([]) do |x, chunk|
        buffer << chunk.data.data
      end
    end

    @contents = buffer
  end

  def destroy
    doc = Place.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id))
    doc.delete_one
  end

  def find_nearest_place_id(max_meters)
    result = Place.near(@location, max_meters).limit(1).projection(:_id=>1).first
    if result
      return result[:_id]#.to_s
    else
      return nil
    end
  end

  def self.find_photos_for_place(id)
    if !id.nil?
      if not id==''
        id = BSON::ObjectId.from_string(id) unless id.class == BSON::ObjectId
      end
    end
    view = Place.mongo_client.database.fs.find('metadata.place'=>id)
  end

end

# {{"_id"=>BSON::ObjectId(’5652d94de301d0c0ad000001’),
# "chunkSize"=>261120,

# "contentType"=>"binary/octet-stream",
# "metadata"=>{"location"=>{"type"=>"Point", "coordinates"=>[-116.30161960177952, 33.87546081542969]}},
# "length"=>601685,
# "md5"=>"871666ee99b90e51c69af02f77f021aa"}}

# "uploadDate"=>2015-11-23 09:15:57 UTC,