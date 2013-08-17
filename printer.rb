require 'rubygems'
require 'serialport'

ESC = 27.chr

class Printer

  SERIALPORT = '/dev/ttyO2'
  BAUDRATE = 19200
  POSITIONS = {:l => 0, :c => 1, :r => 2}


  # pixels with more color value (average for multiple channels) are counted as white
  # tweak this if your images appear too black or too white
  black_threshold = 48
  # pixels with less alpha than this are counted as white
  alpha_threshold = 127

  attr_accessor :printer
  def initialize(heat_time=80, heat_interval=2, heating_dots=7, serialport=SERIALPORT)
    @printer = SerialPort.new(serialport, :baudrate => BAUDRATE)
    @printer.write(ESC) # ESC - command
    @printer.write("@") # @   - initialize
    @printer.write(ESC) # ESC - command
    @printer.write("7") # 7   - print settings
    @printer.write(heating_dots.chr)  # Heating dots (20=balance of darkness vs no jams) default = 20
    @printer.write(heat_time.chr) # heatTime Library default = 255 (max)
    @printer.write(heat_interval.chr) # Heat interval (500 uS = slower, but darker) default = 250

    # Description of print density from page 23 of the manual:
    # DC2 # n Set printing density
    # Decimal: 18 35 n
    # D4..D0 of n is used to set the printing density. Density is 50% + 5% * n(D4-D0) printing density.
    # D7..D5 of n is used to set the printing break time. Break time is n(D7-D5)*250us.
    print_density = 15 # 120% (? can go higher, text is darker but fuzzy)
    print_break_time = 15 # 500 uS
    @printer.write(?\x12)
    @printer.write(?#)
    @printer.write((print_density << 4) | print_break_time).chr)
    @state = {:bold => false, :font_b => false, :inverse => false, :underline => false, :upsidedown => false }
  end
  def reset
     @printer.write(ESC)
     @printer.write(?@)
  end

  def linefeed
    @printer.write(?\n)
  end

  def bold(on=true)
    @printer.write(ESC)
    @printer.write(?E)
    bit = @state[:bold] ? ?\x00 : ?\x01
    @printer.write(bit)
    @state[:bold] = !@state[:bold]
  end

  def font_b
    @printer.write(ESC)
    @printer.write(?!) 
    bit = @state[:font_b] ? ?\x00 : ?\x01
    @printer.write(bit)
    @state[:font_b] = !@state[:font_b]
  end

  def underline 
    @printer.write(ESC)
    @printer.write(?-)
    bit = @state[:underline] ? ?\x00 : ?\x01
    @printer.write(bit)
    @state[:underline] = !@state[:underline]
  end

  def inverse
    @printer.write(?\x1D)
    @printer.write(?B)
    bit = @state[:inverse] ? ?\x00 : ?\x01
    @printer.write(bit)
    @state[:inverse] = !@state[:inverse]
  end

  def upsidedown
    @printer.write(ESC)
    @printer.write(?{)
    bit = @state[:upsidedown] ? 0 : 1
    @printer.write(chr(bit))
    @state[:upsidedown] = !@state[:upsidedown]  
  end

  def print(string)
    @printer.write(string)
  end

  def style(stylesym)
    case stylesym
    when :b
      bold
    when :u
      underline
    when :i
      inverse
    when :f
      font_b
    end
  end

  def print_markup(markup)
    markup.lines.each {|l|
      sym = l[0].to_sym
      align = l[1].to_sym
      content = l[3..-1]
      justify(align)

      style sym
      print content
      style sym
    }
  end

  def justify(align=:l)
    pos = POSITIONS[align]
    @printer.write(ESC)
    @printer.write(?a)
    @printer.write(pos.chr)
  end
end
