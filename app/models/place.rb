# place.rb

class Place

  include ActiveModel::Model

  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize(hash)
    @id = hash[:_id].to_s
    @formatted_address = hash[:formatted_address]
    @location = Point.new(hash[:geometry][:geolocation])
    # @address_components = hash[:address_components]
    @address_components = []
    hash[:address_components].each do |address_component|
      @address_components.push AddressComponent.new(address_component)
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
    _id = BSON::ObjectId.from_string(id)
    place = collection.find(:_id=>_id).first
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

    result = result.to_a.map {|place| place[:_id].to_s}

  end


end