# place.rb

class Place #< ActiveRecord::Base

  #has_many :photos

  include ActiveModel::Model

  attr_accessor :id, :formatted_address, :location, :address_components

  def persisted?
    !@id.nil?
  end

  def initialize(hash)
    @id = hash[:_id].to_s
    @formatted_address = hash[:formatted_address]
    #byebug
    @location = Point.new(hash[:geometry][:geolocation])
    #byebug
    # @address_components = hash[:address_components]
    @address_components = []

    # account for case when address components not given
    # eg in geo_spec
    if !hash[:address_components].nil?
      hash[:address_components].each do |address_component|
        @address_components.push AddressComponent.new(address_component)
      end
    end
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    self.mongo_client['places'] 
  end

  def self.load_all(file)
    hash = JSON.parse(IO.read(file))
    Place.collection.insert_many(hash)
  end

  def self.find_by_short_name(short_name)
    #collection.find.aggregate([{:$match=>{'address_components.short_name'=>short_name}}])
    collection.find('address_components.short_name'=>short_name)
  end

  def self.to_places(view)
    places = []
      view.each do |place|
        places << Place.new(place)
      end
    return places
  end

  def self.find(id)
    # if !id.nil? && !id==''
    #byebug
    if !id.nil?
      if not id==''
        id = BSON::ObjectId.from_string(id) unless id.class == BSON::ObjectId
      end
    end
    place = collection.find(:_id=>id).first
    #byebug
    return place.nil? ? nil : Place.new(place)
  end

  def self.all(offset=0, limit=0)
    docs = collection.find.skip(offset).limit(limit)
    places = []
    docs.each do |doc|
      places << Place.new(doc)
    end
    return places
  end

  def destroy
    self.class.collection.find(:_id=>BSON::ObjectId.from_string(@id)).delete_one
  end

  def self.get_address_components(sort={}, offset=0, limit=0)
    
    agg_array = [
      {:$project=>{:address_components=>1, :formatted_address=>1, 'geometry.geolocation'=>1}},
      {:$unwind=>'$address_components'}
    ]
    agg_array << {:$sort=>sort} unless sort=={}
    agg_array << {:$skip=>offset} unless offset==0
    agg_array << {:$limit=>limit} unless limit==0
    
    collection.find.aggregate(agg_array)

  end

  def self.get_country_names
    result = collection.find.aggregate([
      {:$project=>{'address_components.long_name'=>1, 'address_components.types'=>1}},
      {:$unwind=>'$address_components'},
      {:$match=>{'address_components.types'=>"country"}},
      {:$group=>{:_id=>'$address_components.long_name'}}
    ])

    result = result.to_a.map {|c| c[:_id]}
  end

  def self.find_ids_by_country_code(country_code)

    result = collection.find.aggregate([
      {:$match=>{:$and=>[
        {'address_components.types'=>"country"},{'address_components.short_name'=>country_code}
        ]}},
      {:$project=>{:_id=>1}}
      ])

    result.to_a.map {|place| place[:_id].to_s}

  end

  def self.create_indexes
    collection.indexes.create_one({'geometry.geolocation'=>Mongo::Index::GEO2DSPHERE})
  end

  def self.remove_indexes
    collection.indexes.drop_one('geometry.geolocation_2dsphere')
  end

  def self.near(point, max_meters=0)

    # allow point to be a Point or a Hash
    # Point.to_hash returns a hash based on the @ instance variables
    # Hash.to_hash simply returns itself
    point = point.to_hash

    near = {:$geometry=>{:type=>"Point", :coordinates=>[point[:coordinates][0], point[:coordinates][1]]}}
    near[:$maxDistance] = max_meters unless max_meters==0

    collection.find({
      'geometry.geolocation'=>{
        :$near=>near
      }
    })
  end

  def near(max_meters=0)
    #hash = self.to_hash
    result = self.class.near(self.location, max_meters)
    self.class.to_places(result)
    #places = []
    #result.each do |doc|
    #  places << self.class.to_places(doc)
    #end
  end

  def photos(offset=0, limit=0)
    if limit==0
      view = Photo.mongo_client.database.fs.find('metadata.place'=>BSON::ObjectId.from_string(@id)).skip(offset)
    else 
      view = Photo.mongo_client.database.fs.find('metadata.place'=>BSON::ObjectId.from_string(@id)).skip(offset).limit(limit)
    end

    view = view.to_a
    view.map {|doc| Photo.new(doc)}
  end



end