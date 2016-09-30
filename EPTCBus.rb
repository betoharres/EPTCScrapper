require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'pry'

class EPTCBus
  attr_accessor :id, :url, :name, :code, :current_bus

  def initialize(id, name, code, url)
    @route = :desconhecido
    @day_type = :dias_uteis
    self.id = id.to_s.strip
    self.url = url.to_s.strip
    self.code = code.match(/^\w+/).to_s.to_sym
    self.name = name.match(/(?!^\w+)(?!\s{1,}\-)\s.+(\n|)/m).to_s.strip
    self.current_bus = {@code => {id: id, nome: @name, numero: @code, horarios: {}}}
  end

  def valid?(all_buses = {})
    if ['395-79', '394-27'].include?(@id) || all_buses[@code.to_s]
      return false
    end
  end

  def build(url)
    page = Nokogiri::HTML(open(url))
    raise Exception if page.text.match(/Nenhum registro encontrado/)
    # TODO: find best way to do this
    page.css('b').each do |row|
      row = row.text.strip
      # [directions, week, time].each do |method_call|
      #   begin
      #     method_call(row) if method_call
      #   rescue
      #     next
      #   end
      # end
      begin
        current_bus[:horarios].merge!(directions(row))
      rescue
        begin
          current_bus[:horarios].values.last.merge!(week(row))
        rescue
          begin
            current_bus[:horarios].values.last.values.last
                                            .values.last << time(row)
          rescue
            next
          end
        end
      end
    end
    binding.pry
  end

  def directions(text)
    text = text.to_s.strip
    case text
      when "BAIRRO/CENTRO"
        @route = :ida
        @sentido = "bairro_centro"
      when "CENTRO/BAIRRO"
        @route = :volta
        @sentido = "centro_bairro"
      when "BAIR/CENT/BAIR", "CENT/BAIR/CENT", "TERMINAL/BAIRRO/TERMINAL"
        @route = :circular
        @sentido = "circular"
      when "BAIRRO/TERMINAL"
        @route = :ida
        @sentido = "bairro_terminal"
      when "TERMINAL/BAIRRO"
        @route = :volta
        @sentido = "terminal_bairro"
      when "NORTE/SUL"
        @route = :ida
        @sentido = "norte_sul"
      when "SUL/NORTE"
        @route = :volta
        @sentido = "sul_norte"
      when "NORTE/LESTE"
        @route = :ida
        @sentido = "norte_leste"
      when "LESTE/NORTE"
        @route = :volta
        @sentido = "leste_norte"
      when "LESTE/SUL"
        @route = :ida
        @sentido = "leste_sul"
      when "SUL/LESTE"
        @route = :volta
        @sentido = "sul_leste"
      when "BAIRRO/TERMINAL"
        @route = :ida
        @sentido = "bairro_terminal"
      when "TERMINAL/BAIRRO"
        @route = :volta
        @sentido = "terminal_bairro"
      else
        return
    end
    {@route => {sentido: @sentido}}
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
