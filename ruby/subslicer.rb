#!/usr/bin/ruby

=begin doc
Carlos Villela <cv@lixo.org>
Patrick Hall <pathall@gmail.com>
Copyright 2007, 2009

Based on code from Arne Brasseur, http://www.arnebrasseur.net
Available under the terms of the BSD licence
=end

require 'rubygems'
require 'haml'

module SubSlicer

  class Time
    REGEX = /(\d{2}):(\d{2}):(\d{2}),(\d{3})/

    attr_reader :value

    def self.parse(str)
      hh,mm,ss,ms = str.scan(REGEX).flatten.map{|i| Float(i)}
      value = ((((hh*60)+mm)*60)+ss) + ms/1000
      self.new(value)
    end

    def initialize(value)
      @value = value
    end

    def -(term)
      Time.new(@value - term.value)
    end

    def to_s
      ss = @value.floor
      ms = ((@value - ss)*1000).to_i
      
      mm = ss / 60
      ss = ss - mm * 60

      hh = mm / 60
      mm = mm - hh * 60
      
      "%02i:%02i:%02i,%03i" % [hh, mm, ss, ms]
    end
  end

  class Sub < Struct.new(:index, :from, :to, :sub)
    def to_s
      "#{self.index}
#{self.from} --> #{self.to}
#{self.sub}

"
    end
  end

  class SubList
    TSREGEX = /\d{2}:\d{2}:\d{2},\d{3}/
    REGEX = /(\d+)
(#{TSREGEX}) --> (#{TSREGEX})
(.*?)

/m

    attr_accessor :subs

    def self.load(fn)
      subs = IO.read(fn).scan(REGEX).map do |r| 
        Sub.new(r[0], Time.parse(r[1]), Time.parse(r[2]), r[3])
      end
      self.new subs
    end

    def initialize(subs)
      @subs = subs
    end

    def to_s
      @subs.map {|s| s.to_s}.join
    end
  end
end

def usage
  puts "Usage: #{$0} <movie file> <srt file> <output dir>
  
  movie file:    any movie file ffmpeg understands
  srt file:      a subtitle for the movie file in the srt format
  output dir:    dir where the output will be generated

"
  exit
end

def ffmpeg_cmd(movie, subs, output_dir)
  subs.each do |sub|
    movie_url = "#{output_dir}/#{sub.from.to_s.gsub(/:/, '-').gsub(/,/, '_')}"
    puts "ffmpeg -i #{movie} -ss #{sub.from} -t #{sub.to - sub.from} #{movie_url}.flv"
  end
end

if __FILE__ == $0
  usage if ARGV.size != 3
  
  movie, srt, output_dir = *ARGV
  list = SubSlicer::SubList.load(srt)
  
  ffmpeg_cmd(movie, list.subs, output_dir)

  template = File.read(File.dirname(__FILE__) + '/index.haml')

  haml = Haml::Engine.new(template)
  output = haml.to_html(Object.new, {:subs => list.subs, :output_dir => output_dir})
  puts output

end
