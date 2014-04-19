require 'gosu'

class FurryDangerzone < Gosu::Window

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

	def initialize width=800, height=600, fullscreen=false
		super
		self.caption = "Furry Dangerzone"
    @bg = Gosu::Image.new self, "bg.png"
    @cloud1 = Gosu::Image.new self, "cloud1.png"
    @cloud2 = Gosu::Image.new self, "cloud2.png"
    @furry = Gosu::Image.new self, "furry.png"
    @face = Gosu::Image.new self, "face.png"
    @danger = Gosu::Image.new self, "danger.png"
    @particle = Gosu::Image.new self, "particle.png"
    @jaws = Gosu::Image.new self, "jaws.png"

    @main_text = Gosu::Image.from_text self, "Furry Dangerzone", "./Rase-GPL-Bold.ttf", 64
    @main_outline = Gosu::Image.from_text self, "Furry Dangerzone", "./Rase-GPL-Outline.ttf", 64
    @subtitle_text = Gosu::Image.from_text self, "Press space to jump", "./8-BIT-WONDER.TTF", 30
    @game_over_text = Gosu::Image.from_text self, "game Over", "./Rase-GPL.ttf", 100
    @game_over_outline = Gosu::Image.from_text self, "game Over", "./Rase-GPL-Outline.ttf", 100
    @credits = Gosu::Image.from_text self, "Music by bart from http://opengameart.org", Gosu::default_font_name, 30

    @jump = Gosu::Sample.new self, "jump.wav"
    @explode = Gosu::Sample.new self, "explode.wav"
    @begin = Gosu::Sample.new self, "begin.wav"

    @song = Gosu::Song.new self, "random_silly_chip_song.ogg"
    @song.volume = 0.5
    @song.play true
    reset

    ## GC optimising
    @motion_colors = (0..MOTION_BLUR).map do |i|
      Gosu::Color.new ((1.0 - i.to_f/MOTION_BLUR)*MOTION_BLUR_ALPHA).to_i, 255, 255, 255
    end
	end

	def button_down(id)
		close if id == Gosu::KbEscape
    if @game_over
      reset
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
    @dangers = []
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
      x: x+vx*MOTION_DT*MOTION_BLUR, y: y+vy*MOTION_DT*MOTION_BLUR, vx: vx, vy: vy
    }
  end

  def game_over
    @game_over = true
    @explode.play
    @particles ||= (0..NUM_PARTICLES).map do
      make_particle FURRY_OFFSET, @pos, Gosu::random(0,1.5)*PARTICLE_V
    end
  end

  def make_danger
    {
      pos: Gosu::random(DANGER_OFFSET, self.height-DANGER_OFFSET*2),
      dist: self.width+DANGER_OFFSET
    }
  end

  def length_sq x, y
    x*x + y*y
  end

  def distance_sq x1, y1, x2, y2
    length_sq x1-x2, y1-y2
  end


  def squared x
    x*x
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
        Gosu.random(1,3).to_int.times do
          @dangers << make_danger
        end
        @last_danger = new_time
      end

      if @pos < @furry.height/2 || @pos > self.height-@furry.height/2
        game_over
      else
        @dangers.each do |danger|
          danger_sq = distance_sq(danger[:dist], danger[:pos], FURRY_OFFSET, @pos)
          if danger_sq < squared(@furry.width)
            game_over
          end
        end
      end

      @score += SCORE_PER_SECOND*@dt
      @score_text = Gosu::Image.from_text self, "Score #{@score.to_i}", "./8-BIT-WONDER.TTF", 30

    end

    unless @game_over
      if length_sq(@gravity*@dt,@speed*@dt) > squared(HISTORY_DISTANCE)
        @history << @pos
        @history.shift if @history.length > MOTION_BLUR
        @last_history = new_time
      end
    end

    @dangers.each do |danger|
      danger[:dist] -= @dt*@speed
    end

    @dangers.delete_if { |danger| danger[:dist] < -DANGER_OFFSET }

    if @particles
      @particles.each do |particle|
        particle[:x] += particle[:vx]*@dt
        particle[:y] += particle[:vy]*@dt
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
    draw_bg @jaws, @dist, self.height-@jaws.height
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
      (1..MOTION_BLUR).each do |i|
        offset = i*MOTION_BLUR_OFFSET
        @danger.draw danger[:dist]-@danger.width/2+offset, danger[:pos]-@danger.height/2, 0, 1, 1, @motion_colors[i]
      end
      @danger.draw danger[:dist]-@danger.width/2, danger[:pos]-@danger.height/2, 0
    end

    if @particles
      (1..MOTION_BLUR).each do |i|
        xoffset = i*MOTION_BLUR_OFFSET*0.4
        @particles.each do |particle|
          yoffset = i*particle[:vy]*MOTION_DT
          @particle.draw particle[:x]-@particle.width-xoffset, particle[:y]-@particle.height-yoffset, 0, 1, 1, @motion_colors[i]
        end
      end
      @particles.each do |particle|
        @particle.draw particle[:x]-@particle.width, particle[:y]-@particle.height, 0
      end

    end

    unless @playing
      @main_text.draw self.width/2-@main_text.width/2, 50, 0, 1, 1, 0xFFFF00FF
      @main_outline.draw self.width/2-@main_outline.width/2, 50, 0, 1, 1, 0xFF000000

      @subtitle_text.draw self.width/2-@subtitle_text.width/2, 150, 0, 1, 1, 0xFF000000

      @credits.draw 20, self.height-20-@credits.height, 0, 1, 1, 0xFFFFFFFF
    else
      @score_text.draw 20, 20, 0, 1, 1, 0xFF000000 unless @game_over
    end

    if @game_over
      @game_over_text.draw self.width/2-@game_over_text.width/2, self.height/2-@game_over_text.height/2, 0, 1, 1, 0xFFFF00FF
      @game_over_outline.draw self.width/2-@game_over_outline.width/2, self.height/2-@game_over_outline.height/2, 0, 1, 1, 0xFF000000
    
      @score_text.draw self.width/2-@score_text.width/2, self.height/2+50, 0, 1, 1, 0xFF000000
    end
	end

end

FurryDangerzone.new.show
