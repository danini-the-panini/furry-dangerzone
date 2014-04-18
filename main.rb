require 'gosu'

class FurryDangerzone < Gosu::Window

  BOUNCE_AMOUNT = 500.0
  GRAVITY = 1500.0
  FURRY_OFFSET = 100.0
  DANGER_OFFSET = 50.0
  DANGER_PERIOD = 0.3
  SPEED = 500.0
  NUM_PARTICLES = 100
  PARTICLE_V = 100.0

	def initialize width=800, height=600, fullscreen=false
		super
		self.caption = "Furry Dangerzone"
    @bg = Gosu::Image.new self, "bg.png"
    @cloud1 = Gosu::Image.new self, "cloud1.png"
    @cloud2 = Gosu::Image.new self, "cloud2.png"
    @furry = Gosu::Image.new self, "furry.png"
    @danger = Gosu::Image.new self, "danger.png"
    @particle = Gosu::Image.new self, "particle.png"

    @main_text = Gosu::Image.from_text self, "Furry Dangerzone", "./Rase-GPL-Bold.ttf", 63
    @main_outline = Gosu::Image.from_text self, "Furry Dangerzone", "./Rase-GPL-Outline.ttf", 64
    @subtitle_text = Gosu::Image.from_text self, "Press space to jump", "./8-BIT-WONDER.TTF", 30
    @game_over_text = Gosu::Image.from_text self, "game Over", "./Rase-GPL.ttf", 100
    @game_over_outline = Gosu::Image.from_text self, "game Over", "./Rase-GPL-Outline.ttf", 100
    reset
	end

	def button_down(id)
		close if id == Gosu::KbEscape
    if @game_over
      reset
    elsif @playing
      @velocity = -BOUNCE_AMOUNT if Gosu::KbSpace
    else
      @playing = true
      @last_time = Gosu::milliseconds
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
  end

  def make_particle x, y, v
    theta = Gosu.random(0,2*Math::PI)
    {
      x: x, y: y, vx: v*Math::cos(theta), vy: v*Math::sin(theta)
    }
  end

  def game_over
    @game_over = true
    @particles ||= (0..NUM_PARTICLES).map do
      make_particle FURRY_OFFSET, @pos, Gosu::random(0.2,1.5)*PARTICLE_V
    end
  end

  def make_danger
    {
      pos: Gosu::random(DANGER_OFFSET, self.height-DANGER_OFFSET*2),
      dist: self.width+DANGER_OFFSET
    }
  end

  def distance_sq x1, y1, x2, y2
    dx = x1-x2
    dy = y1-y2
    dx*dx + dy*dy
  end

  def squared x
    x*x
  end

	def update
    new_time = Gosu::milliseconds
    @dt = (new_time - @last_time)/1000.0
    @last_time = new_time

    if @playing && !@game_over
      @dist -= (@dt*@speed).to_i
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

  def draw_bg image, dist, pos
    translate dist % image.width, 0 do
      image.draw 0, pos, 0
      image.draw -image.width, pos, 0
    end
  end

	def draw
    draw_bg @bg, @dist/8, 0
    draw_bg @cloud1, @dist/4, -(@pos-self.height/2)/4
    draw_bg @cloud2, @dist/2, -(@pos-self.height/2)/2

    @furry.draw FURRY_OFFSET-@furry.width/2, @pos-@furry.height/2, 0 unless @game_over

    @dangers.each do |danger|
      @danger.draw danger[:dist]-@danger.width/2, danger[:pos]-@danger.height/2, 0
    end

    if @particles
      @particles.each do |particle|
        @particle.draw particle[:x]-@particle.width, particle[:y]-@particle.height, 0
      end
    end

    unless @playing
      @main_text.draw self.width/2-@main_text.width/2, 50, 0, 1, 1, 0xFFFF00FF
      @main_outline.draw self.width/2-@main_outline.width/2, 50, 0, 1, 1, 0xFF000000

      @subtitle_text.draw self.width/2-@subtitle_text.width/2, 150, 0, 1, 1, 0xFF000000
    else
    end

    if @game_over
      @game_over_text.draw self.width/2-@game_over_text.width/2, self.height/2-@game_over_text.height/2, 0, 1, 1, 0xFFFF00FF
      @game_over_outline.draw self.width/2-@game_over_outline.width/2, self.height/2-@game_over_outline.height/2, 0, 1, 1, 0xFF000000
    end
	end

end

FurryDangerzone.new.show