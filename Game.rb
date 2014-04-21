require 'gosu'
require 'fileutils'

# constants
BOUNCE_AMOUNT = 500.0
GRAVITY = 1500.0
FURRY_OFFSET = 100.0
DANGER_OFFSET = 50.0
DANGER_PERIOD = 0.3
SPEED = 500.0
NUM_PARTICLES = 200
PARTICLE_V = 500.0
SCORE_PER_SECOND = 10
MOTION_BLUR = 10
MOTION_BLUR_OFFSET = 5.0
MOTION_BLUR_ALPHA = 64.0
HISTORY_DISTANCE = 5
MOTION_DT = 0.01
MOTION_ANGLE_FACTOR = 0.1
GAME_OVER_DELAY = 0.3
MAX_SCORES = 7

LEVEL_UP = 150
LEVELS = [ [0.2,0.8],
           [0.15,0.6],
           [0.1,0.6],
           [0.05,0.5],
           [0,0.5] ]

DATA_DIR = File.expand_path('~/.jellymann/furry-dangerzone')
SCORE_FILE = DATA_DIR+'/scores.dat'

# helpers
def length_sq x, y
  x*x + y*y
end

def distance_sq x1, y1, x2, y2
  length_sq x1-x2, y1-y2
end

def squared x
  x*x
end

def max x, y
  x>y ? x : y
end

def min x, y
  x>y ? y : x
end

class Score
  def initialize window, font, font_height
    @text = Gosu::Image.from_text window, "Score ", font, font_height
    @numbers = 10.times.map do |i|
      Gosu::Image.from_text window, i.to_s, font, font_height
    end
  end

  def draw x, y, score
    @text.draw x, y, 0, 1, 1, 0xFF000000
    dx = @text.width
    num_list(score).each do |i|
      num = @numbers[i]
      num.draw x+dx, y, 0, 1, 1, 0xFF000000
      dx += num.width
    end
  end

  def width score
    w = @text.width
    num_list(score).each do |i|
      w += @numbers[i].width
    end
    w
  end

  private
  def num_list score
    nums = []
    while score > 0
      nums << score%10
      score /= 10
    end
    nums.reverse
  end
end

class Danger
  def initialize image
    @image = image
  end

  def reset window
    @pos = Gosu::random(DANGER_OFFSET, window.height-DANGER_OFFSET*2)
    @dist = window.width+DANGER_OFFSET
    @av = Gosu::random(-180, -90)
    @a = Gosu::random(0, 360)
    self
  end

  def update dt, speed
    @dist -= dt*speed
    @a += dt*@av
  end

  def draw motion_colors
    (1..MOTION_BLUR).each do |i|
      offset = i*MOTION_BLUR_OFFSET*2
      angle = @a-i*@av*MOTION_ANGLE_FACTOR
      @image.draw_rot @dist+offset, @pos, 0, angle, 0.5, 0.5, 1, 1, motion_colors[i]
    end
    @image.draw_rot @dist, @pos, 0, @a
  end

  def gone_off?
    @dist < -DANGER_OFFSET
  end

  def close_to? x, y, radius
    distance_sq(@dist, @pos, x, y) < squared(radius+@image.width/2)
  end
end

class DangerPool
  def initialize window, size
    @danger_image = Gosu::Image.new window, "danger.png"
    @free = size.times.map { |i| Danger.new @danger_image }
    @used = []
  end

  def each &block
    @used.each &block
  end

  def delete_if &block
    @used.delete_if do |danger|
      if block.(danger)
        @free << danger
        true
      else
        false
      end
    end
  end

  def allocate window
    if @free.empty?
      obj = Danger.new(@danger_image)
    else
      obj = @free.pop
    end
    @used << obj.reset(window)
    obj
  end

  # def deallocate danger
  #   @used.delete danger
  #   @free << danger
  # end

  def reset
    @free.concat @used
    @used = []
  end
end

class FurryDangerzone < Gosu::Window

	def initialize width=800, height=600, fullscreen=false
		super
		self.caption = "Furry Dangerzone"
    @bg = Gosu::Image.new self, "bg.png"
    @cloud1 = Gosu::Image.new self, "cloud1.png"
    @cloud2 = Gosu::Image.new self, "cloud2.png"
    @furry = Gosu::Image.new self, "furry.png"
    @face = Gosu::Image.new self, "face.png"
    @particle = Gosu::Image.new self, "particle.png"
    @jaws = Gosu::Image.new self, "jaws.png"
    @jaws2 = Gosu::Image.new self, "jaws2.png"
    @jaws3 = Gosu::Image.new self, "jaws3.png"
    @dangers = DangerPool.new self, 10

    @main_text = Gosu::Image.from_text self, "Furry Dangerzone", "./Rase-GPL-Bold.ttf", 64
    @main_outline = Gosu::Image.from_text self, "Furry Dangerzone", "./Rase-GPL-Outline.ttf", 64
    @subtitle_text = Gosu::Image.from_text self, "Press space to jump", "./8-BIT-WONDER.TTF", 30
    @game_over_text = Gosu::Image.from_text self, "game Over", "./Rase-GPL.ttf", 100
    @game_over_outline = Gosu::Image.from_text self, "game Over", "./Rase-GPL-Outline.ttf", 100
    @credits = Gosu::Image.from_text self, "Music by bart from http://opengameart.org", Gosu::default_font_name, 30
    @score_text = Score.new self, "./8-BIT-WONDER.TTF", 30
    @prompt = Gosu::Image.from_text self, "You got a high score", "./8-BIT-WONDER.TTF", 30
    @prompt_not_good_enough = Gosu::Image.from_text self, "Press any key to continue", "./8-BIT-WONDER.TTF", 30

    @jump = Gosu::Sample.new self, "jump.wav"
    @explode = Gosu::Sample.new self, "explode.wav"
    @begin = Gosu::Sample.new self, "begin.wav"

    @song = Gosu::Song.new self, "random_silly_chip_song.ogg"
    @song.volume = 0.5
    @song.play true

    load_scores
    update_score_strings

    reset

    ## GC optimising
    @motion_colors = (0..MOTION_BLUR).map do |i|
      Gosu::Color.new ((1.0 - i.to_f/MOTION_BLUR)*MOTION_BLUR_ALPHA).to_i, 255, 255, 255
    end
	end

  def load_scores
    if File.exists?(SCORE_FILE)
      File.open(SCORE_FILE) do |f|
        @scores = Marshal::load(f.read)
      end
    else
      @scores = []
    end
  end

  def save_scores
    FileUtils.mkpath DATA_DIR
    File.open(SCORE_FILE, File::CREAT|File::TRUNC|File::RDWR) do |f|
      f.write Marshal::dump(@scores)
    end
  end

  def update_score_strings
    @score_strings = @scores.map do |score,name|
      [Gosu::Image.from_text(self, score.to_s, "./8-BIT-WONDER.TTF", 30),
        Gosu::Image.from_text(self, name, "./8-BIT-WONDER.TTF", 30)]
    end
  end

  def made_high_score?
    (@scores.length<MAX_SCORES || @score > @scores[-1][0])
  end

	def button_down(id)
		close if id == Gosu::KbEscape
    if @game_over
      unless @game_over_time < GAME_OVER_DELAY
        if self.text_input
          if id == Gosu::KbReturn || id == Gosu::KbEnter
            @scores << [@score.to_i, self.text_input.text]
            @scores = @scores.sort{ |x,y| y <=> x }.slice(0...MAX_SCORES)
            update_score_strings
            save_scores
            self.text_input = nil
            reset
          end
        else
          reset
        end
      end
    elsif @playing
      if Gosu::KbSpace
        @velocity = -BOUNCE_AMOUNT 
        @jump.play
      end
    else
      @playing = true
      @last_time = Gosu::milliseconds
      @begin.play
    end
	end

  def reset
    @speed = SPEED
    @dist = 0;
    @pos = height/2
    @gravity = GRAVITY
    @velocity = 0
    @dt = 0
    @last_time = 0
    @playing = false
    @dangers.reset
    @danger_period = DANGER_PERIOD
    @last_danger = @last_time
    @game_over = false
    @particles = nil
    @score = 0
    @history = []
    @last_history = 0
  end

  def make_particle x, y, v
    theta = Gosu.random(0,2*Math::PI)
    vx = v*Math::cos(theta)
    vy = v*Math::sin(theta)
    {
      x: x+vx*MOTION_DT*MOTION_BLUR, y: y+vy*MOTION_DT*MOTION_BLUR, vx: vx, vy: vy,
      av: Gosu.random(45,180), a: Gosu.random(0,360)
    }
  end

  def game_over
    GC.start
    @game_over = true
    @game_over_time = 0
    @explode.play
    @particles ||= (0..NUM_PARTICLES).map do
      make_particle FURRY_OFFSET, @pos, Gosu::random(0.01,1.5)*PARTICLE_V
    end
  end

	def update
    new_time = Gosu::milliseconds
    @dt = (new_time - @last_time)/1000.0
    @last_time = new_time
    @dist -= (@dt*@speed).to_i

    if @playing && !@game_over
      @velocity += @gravity*@dt
      @pos += @velocity*@dt

      if (new_time - @last_danger)/1000.0 > @danger_period
        r = Gosu.random(0,1)
        
        level = LEVELS[min(@score/LEVEL_UP, LEVELS.length-1)]

        amount = level.length

        level.each_index do |i|
          # puts "#{r} < #{level[i]} ???"
          if r < level[i]
            amount = i
            break
          end
        end

        # puts amount

        amount.times do
          @dangers.allocate self
        end

        @last_danger = new_time
      end

      if @pos < @furry.height/2 || @pos > self.height-@furry.height/2
        game_over
      else
        @dangers.each do |danger|
          if danger.close_to?(FURRY_OFFSET, @pos, @furry.width/2)
            game_over
          end
        end
      end

      @score += SCORE_PER_SECOND*@dt

    end

    unless @game_over
      if length_sq(@gravity*@dt,@speed*@dt) > squared(HISTORY_DISTANCE)
        @history << @pos
        @history.shift if @history.length > MOTION_BLUR
        @last_history = new_time
      end
    else
      @game_over_time += @dt unless @game_over_time > GAME_OVER_DELAY
      if @game_over_time > GAME_OVER_DELAY && made_high_score? && !self.text_input
        self.text_input = Gosu::TextInput.new
      end
    end

    @dangers.each do |danger|
      danger.update @dt, @speed
    end

    @dangers.delete_if { |danger| danger.gone_off? }

    if @particles
      @particles.each do |particle|
        particle[:x] += particle[:vx]*@dt
        particle[:y] += particle[:vy]*@dt
        particle[:a] += particle[:av]*@dt
      end
    end
	end

  def draw_bg image, dist, pos, factor_x = 1, factor_y = 1, color = 0xffffffff, mode = :default
    translate dist % image.width, 0 do
      image.draw 0, pos, 0, factor_x, factor_y, color, mode
      image.draw -image.width, pos, 0, factor_x, factor_y, color, mode
    end
  end

	def draw
    draw_bg @bg, @dist/8, 0
    draw_bg @cloud1, @dist/4, -(@pos-self.height/2)/8
    draw_bg @cloud2, @dist/2, -(@pos-self.height/2)/4
    draw_bg @jaws3, @dist/4, self.height-@jaws.height-(@pos)/16, 1, 1, 0xFF9bc2fd
    draw_bg @jaws2, @dist/2, self.height-@jaws.height-(@pos)/32, 1, 1, 0xFFc2dafd
    draw_bg @jaws, @dist, self.height-@jaws.height
    draw_bg @jaws3, @dist/4, @jaws.height-(@pos-self.height)/16, 1, -1, 0xFF88edff
    draw_bg @jaws2, @dist/2, @jaws.height-(@pos-self.height)/32, 1, -1, 0xFFcdf7ff
    draw_bg @jaws, @dist, @jaws.height, 1, -1

    unless @game_over
      offset = 0
      @history.each_index do |i|
        offset = i*MOTION_BLUR_OFFSET
        @furry.draw FURRY_OFFSET-@furry.width/2-offset, @history[@history.length-i-1]-@furry.height/2, 0, 1, 1, @motion_colors[i]
      end
      @furry.draw FURRY_OFFSET-@furry.width/2, @pos-@furry.height/2, 0
      @face.draw FURRY_OFFSET-2, @pos-2+5*(@velocity/600), 0
    end

    @dangers.each do |danger|
      danger.draw @motion_colors
    end

    if @particles
      (1..MOTION_BLUR).each do |i|
        xoffset = i*MOTION_BLUR_OFFSET*0.4
        @particles.each do |particle|
          yoffset = i*particle[:vy]*MOTION_DT
          angle = particle[:a]-i*particle[:av]*MOTION_ANGLE_FACTOR
          @particle.draw_rot particle[:x]-xoffset, particle[:y]-yoffset, 0, angle, 0.5, 0.5, 1, 1, @motion_colors[i]
        end
      end
      @particles.each do |particle|
        @particle.draw_rot particle[:x], particle[:y], 0, particle[:a]
      end

    end

    unless @playing
      @main_text.draw self.width/2-@main_text.width/2, 50, 0, 1, 1, 0xFFFF00FF
      @main_outline.draw self.width/2-@main_outline.width/2, 50, 0, 1, 1, 0xFF000000

      @subtitle_text.draw self.width/2-@subtitle_text.width/2, 150, 0, 1, 1, 0xFF000000

      @credits.draw 20, self.height-20-@credits.height, 0, 1, 1, 0xFFFFFFFF

      dy = 0
      @score_strings.each do |score,name|
        name.draw FURRY_OFFSET*1.5, 200+dy, 0, 1, 1, 0xFF000000
        score.draw self.width-FURRY_OFFSET*1.5-score.width, 200+dy, 0, 1, 1, 0xFF000000
        dy += 50
      end
    else
      @score_text.draw 20, 20, @score.to_i unless @game_over
    end

    if @game_over
      @game_over_text.draw self.width/2-@game_over_text.width/2, self.height/2-@game_over_text.height/2, 0, 1, 1, 0xFFFF00FF
      @game_over_outline.draw self.width/2-@game_over_outline.width/2, self.height/2-@game_over_outline.height/2, 0, 1, 1, 0xFF000000
    
      @score_text.draw self.width/2-@score_text.width(@score.to_i)/2, self.height/2+50, @score.to_i

      if @game_over_time > GAME_OVER_DELAY
        if self.text_input
          @prompt.draw self.width/2-@prompt.width/2, self.height/2+100, 0, 1, 1, 0xFF000000

          caret = self.text_input.caret_pos
          before_text = caret.zero? ? "" : self.text_input.text[0..caret-1]
          after_text = self.text_input.text[caret..-1]
          name_before = Gosu::Image.from_text(self, "*"+before_text+"|", "./8-BIT-WONDER.TTF", 30)
          name_after = Gosu::Image.from_text(self, after_text+"*", "./8-BIT-WONDER.TTF", 30)
          input_width = name_before.width + name_after.width
          name_before.draw self.width/2-input_width/2, self.height/2+130, 0, 1, 1, 0xFF000000
          name_after.draw self.width/2-input_width/2+name_before.width, self.height/2+130, 0, 1, 1, 0xFF000000
        else
          if Time::now.to_f % 1.4 < 0.7
            @prompt_not_good_enough.draw self.width/2-@prompt_not_good_enough.width/2, self.height/2+100, 0, 1, 1, 0xFF000000
          end
        end
      end
    end
	end

end

FurryDangerzone.new.show
