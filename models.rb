# frozen_string_literal: true

require 'active_record'

# ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'schedules.db'
)
ActiveRecord::Schema.define do
  create_table :buses, if_not_exists: true do |t|
    t.string :identifier, limit: 10, unique: true
    t.string :name,       limit: 70
    t.string :code,       limit: 8
    t.string :url,        unique: true
  end

  create_table :schedules, if_not_exists: true do |t|
    t.integer  :direction,   limit:   1, default: 0
    t.integer  :dayType,     limit:   1, default: 0
    t.integer  :hour,        limit:   1, default: 0
    t.integer  :minute,      limit:   1, default: 0
    t.string   :time,        limit:   5
    t.datetime :timeDateTime
    t.boolean  :isHandicap,   default: false
    t.boolean  :isSummerTime, default: false
  end

  create_table :bus_stops, if_not_exists: true do |t|
    t.references :bus, index: false
    t.references :schedule, index: false
  end
end

# bus model
class Bus < ActiveRecord::Base
  has_many :bus_stops
  has_many :schedules, through: :bus_stops
end

# schedule model
class Schedule < ActiveRecord::Base
  has_many :bus_stops
  has_many :buses, through: :bus_stops
end

# bus stop model
class BusStop < ActiveRecord::Base
  belongs_to :bus
  belongs_to :schedule
end
