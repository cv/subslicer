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
require 'fileutils'

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

    def +(time)
      Time.new(@value + time.value)
    end

    def -(time)
      Time.new(@value - time.value)
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

    def self.load(file)
      subs = IO.read(file).scan(REGEX).map do |r| 
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

  class Main < Struct.new(:movie, :srt, :output_dir, :subs)

    def initialize(movie, srt, output_dir)
      self.movie = movie
      self.srt = srt
      self.output_dir = output_dir
      self.subs = SubSlicer::SubList.load(srt).subs
    end
    
    def process!
      clobber_output
      # add_some_padding
      ffmpeg
      generate_index
      copy_assets
    end
    
    def clobber_output
      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)
    end
    
    def add_some_padding
      subs.each do |sub|
        sub.from -= Time.parse('00:00:00,500')
        sub.to   += Time.parse('00:00:00,500')
      end
    end

    def ffmpeg
      subs.map do |sub|
        movie_url = "#{output_dir}/#{sub.from.to_s.gsub(/:/, '-').gsub(/,/, '_')}"
        `ffmpeg -i '#{movie}' -ss '#{sub.from}' -t '#{sub.to - sub.from}' '#{movie_url}.flv'`
      end
    end

    def generate_index
      template = File.read(File.dirname(__FILE__) + '/index.haml')

      open(File.join(output_dir, 'index.html'), 'w') do |out|
        locals = {:subs => subs, :output_dir => output_dir}
        out.write(Haml::Engine.new(template).render(Object.new, locals))
      end
    end

    def copy_assets
      FileUtils.cp_r Dir[File.join(File.dirname(__FILE__), 'assets', '*')], output_dir
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

if __FILE__ == $0
  usage if ARGV.size != 3
  SubSlicer::Main.new(*ARGV).process!
end
