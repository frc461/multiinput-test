#!/home/brad/.rbenv/shims/ruby

require './libdevinput.rb'
require 'curses'
require 'yaml'

raw_config = File.read('./config.yml')
CONFIG = YAML.load(raw_config)


`stty -echo`

class Scout

    def initialize dev, win, pos
        @dev = DevInput.new dev
        @win = win
        @position = pos
        @win.refresh
        @win.box 'x', 'x'
        @win.setpos 2,2
        @win.addstr @position
    end

    def run
        @dev.each do |event|
            # reject everything but key events
            next unless event.type == 1
            # reject everything but press events
            next unless event.value == 1
            # ignore numlock
            next if event.code == 69
            @win.clear
            @win.box 'x', 'x'
            @win.setpos 2,2
            @win.addstr @position
            @win.setpos(2,12)
            @win.addstr(event.code_str)
            @win.setpos(4,12)
            @win.addstr(event.code.to_s)
            @win.refresh
        end
        @win.clear
        @win.getch
    end

    def safe
       true 
    end

end


include Curses

init_screen
noecho
cbreak

pool = []
workers = []


begin

    r1win = Window.new(8, cols / 2 - 5, 2, 2)
    worker = Scout.new '/dev/input/event' + CONFIG['devs']['R1'].to_s, r1win, "R1"
    workers << worker
    pool << Thread.new{ worker.run }

    r2win = Window.new(8, cols / 2 - 5, 10, 2)
    worker = Scout.new '/dev/input/event' + CONFIG['devs']['R2'].to_s, r2win, "R2"
    workers << worker
    pool << Thread.new{ worker.run }

    r3win = Window.new(8, cols / 2 - 5, 20, 2)
    worker = Scout.new '/dev/input/event' + CONFIG['devs']['R3'].to_s, r3win, "R3"
    workers << worker
    pool << Thread.new{ worker.run }

    b1win = Window.new(8, cols / 2 - 5, 2, cols / 2 + 1)
    worker = Scout.new '/dev/input/event' + CONFIG['devs']['B1'].to_s, b1win, "B1"
    workers << worker
    pool << Thread.new{ worker.run }

    b2win = Window.new(8, cols / 2 - 5, 10, cols / 2 + 1)
    worker = Scout.new '/dev/input/event' + CONFIG['devs']['B2'].to_s, b2win, "B2"
    workers << worker
    pool << Thread.new{ worker.run }

    b3win = Window.new(8, cols / 2 - 5, 20, cols / 2 + 1)
    worker = Scout.new '/dev/input/event' + CONFIG['devs']['B3'].to_s, b3win, "B3"
    workers << worker
    pool << Thread.new{ worker.run }


    refresh

    trap "SIGINT" do
        safe = true
        workers.each do |w|
            safe = false unless w.safe
        end
    
        if safe
            close_screen
            pool.each(&:kill)

            puts "Goodbye"
        else
        end
    end

    pool.each(&:join)
ensure
    close_screen
    `stty echo`
    `clear`
end
