#!/usr/bin/ruby

=begin doc
Arne Brasseur, http://www.arnebrasseur.net
Copyright 2007
Freely available under the terms of the BSD licence

Suppose you have a .srt file with subtitles, 
it's a textfile that looks like this:


1
00:00:54,788 --> 00:00:57,222
Besides the constant urge and inability to pee...

2
00:00:57,290 --> 00:00:59,087
Are there other symptoms?

3
00:01:08,835 --> 00:01:10,700
I'll just have a look.


You also have a movie file, you try to play it with 
mplayer the subs using mplayer but they're badly out of sync.

Play the movie again with mplayer and pause it (space)
at a point in the beginning where you know a certain
subtitle should start, e.g. subtitle 3 : "I'll just have a look"

Now look at your terminal, the last line looks like this:

A:12.2 V:12.2 A-V:  0.000 ct:  0.048 30580/30580  4%  0%  1.1% 0 0

That first number 12.2 is the current position in seconds, take note of this.

Repeat this but this time for a subtitle somewhere at the end of the movie.

Now use subscale.rb to reposition the subtitles:

subscale.rb Filename.srt 3 12.2 1130 5357.4 > new_subtitles.srt

=end


module SubScaler
  class <<self
    def scale(filename, percentage)
      puts( SubList.load(filename) * Float(percentage) )
    end

    def reposition(filename, id1, time1, id2, time2)
      id1, id2, time1, time2 = Integer(id1), Integer(id2), Float(time1), Float(time2)
      subs = SubList.load(filename)

      orig_diff = subs[id2].from.value - subs[id1].from.value
      new_diff = time2 - time1
      subs *= (new_diff / orig_diff)
      subs += time1 - subs[id1].from.value

      puts subs
    end
  end

  class Time
    REGEX = /(\d{2}):(\d{2}):(\d{2}),(\d{3})/

    attr_reader :value

    class <<self
      def parse(str)
        hh,mm,ss,ms = str.scan(REGEX).flatten.map{|i| Float(i)}
        value = ((((hh*60)+mm)*60)+ss) + ms/1000
        self.new(value)
      end
    end

    def initialize(value)
      @value = value
    end

    def *(factor)
      Time.new(@value * factor)
    end

    def +(term)
      Time.new(@value + term)
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
    def *(factor)
      Sub.new(self.index, self.from * factor, self.to * factor, self.sub)
    end

    def +(term)
      Sub.new(self.index, self.from + term, self.to + term, self.sub)
    end
    
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

    class <<self
      def load(fn)
        subs = IO.read(fn).scan(REGEX).map do |r| 
          Sub.new(r[0], Time.parse(r[1]), Time.parse(r[2]), r[3])
        end
        self.new subs
      end
    end

    def initialize(subs)
      @subs = subs
    end

    def *(factor)
      SubList.new(@subs.map {|s| s * factor})
    end

    def +(term)
      SubList.new(@subs.map {|s| s + term})
    end

    def [](i)
      @subs[i-1]
    end

    def to_s
      @subs.map {|s| s.to_s}.join
    end
  end
end

if __FILE__ == $0
  if ARGV.length == 2
    SubScaler.scale(ARGV[0], ARGV[1])
  elsif ARGV.length == 5
    SubScaler.reposition(*ARGV[0..5])
  else
    puts %{
Usage: 
  #{File.basename $0} filename percentage
  #{File.basename $0} filename index1 time1 index2 time2
}
  end
end
