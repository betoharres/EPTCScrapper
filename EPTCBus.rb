require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'pry'

class EPTCBus
  attr_accessor :id, :url, :name, :code, :info

  def initialize(id, name, code, url)
    @route = :desconhecido
    @day_type = :dias_uteis
    self.id = id.to_s.strip
    self.url = url.to_s.strip
    self.code = code.match(/^\w+/).to_s.to_sym
    self.name = name.match(/(?!^\w+)(?!\s{1,}\-)\s.+(\n|)/m).to_s.strip
    self.info = {@code => {id: id, nome: @name, numero: @code, horarios: {}}}
  end

  def valid?(all_buses = {})
    if ['395-79', '394-27'].include?(@id) || all_buses[@code.to_s]
      return false
    end
  end

  def build(options = {sleep: 1})
    sleep options[:sleep]
    page = Nokogiri::HTML(open(self.url))
    raise StandardError, "Nenhum horario encontrado em #{self.name}" if page.text.match(/Nenhum registro encontrado/)
    # TODO: find best way to do this
    # maybe page.text and then search schedules with regex
    page.css('b').each do |row|
      row = row.text.strip
      if directions(row)
        self.info[@code][:horarios].merge!(directions(row))
      elsif week(row)
        self.info[@code][:horarios].values.last.merge!(week(row))
      elsif time(row)
        self.info[@code][:horarios].values.last.values.last << time(row)
      end
    end
    self.info
  end

  def directions(text)
    text = text.to_s.strip
    case text
      when "BAIRRO/CENTRO"
        @route = :ida
        @direction = "bairro_centro"
      when "CENTRO/BAIRRO"
        @route = :volta
        @direction = "centro_bairro"
      when "BAIR/CENT/BAIR", "CENT/BAIR/CENT", "TERMINAL/BAIRRO/TERMINAL"
        @route = :circular
        @direction = "circular"
      when "BAIRRO/TERMINAL"
        @route = :ida
        @direction = "bairro_terminal"
      when "TERMINAL/BAIRRO"
        @route = :volta
        @direction = "terminal_bairro"
      when "NORTE/SUL"
        @route = :ida
        @direction = "norte_sul"
      when "SUL/NORTE"
        @route = :volta
        @direction = "sul_norte"
      when "NORTE/LESTE"
        @route = :ida
        @direction = "norte_leste"
      when "LESTE/NORTE"
        @route = :volta
        @direction = "leste_norte"
      when "LESTE/SUL"
        @route = :ida
        @direction = "leste_sul"
      when "SUL/LESTE"
        @route = :volta
        @direction = "sul_leste"
      when "BAIRRO/TERMINAL"
        @route = :ida
        @direction = "bairro_terminal"
      when "TERMINAL/BAIRRO"
        @route = :volta
        @direction = "terminal_bairro"
      else
        return
    end
    {@route => {sentido: @direction}}
  end

  def week(text)
    case text
      when "Dias Úteis"
        @day_type = :dias_uteis
      when "Sábados"
        @day_type = :sabado
      when "Domingos"
        @day_type = :domingo
      else
        return
    end
    {@day_type => []}
  end

  def bus_for_disabled?(text)
    text.to_s.match(/APD\.gif/) ? true : false
  end

  def time(text)
    schedule = text.match(/(\d{2})[:](\d{2})/)
    return if schedule.nil?
    if bus_for_disabled?(text)
      [[schedule[1].to_i, schedule[2].to_i], cadeirante: true]
    else
      [[schedule[1].to_i, schedule[2].to_i], cadeirante: false]
    end
  end
end
