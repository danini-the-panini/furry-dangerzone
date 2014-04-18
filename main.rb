require 'gosu'

class FurryDangerzone < Gosu::Window

	def initialize width=800, height=600, fullscreen=false
		super
		self.caption = "Furry Dangerzone"
	end

	def button_down(id)
		close if id == Gosu::KbEscape
	end

	def update
	end

	def draw
	end

end

FurryDangerzone.new.show