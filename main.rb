#!/home/brad/.rbenv/shims/ruby

require './libdevinput.rb'
require 'curses'
require 'json'
require 'httparty'
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
        @data = {}
        @state = :prestart
        @team = ''
    end

    def run
        @dev.each do |event|
            # reject everything but key events
            next unless event.type == 1
            # reject everything but press events
            next unless event.value == 1
            # ignore numlock
            next if event.code == 69

            case @state
            when :prestart
                case event.code_str
                when /[0-9]/
                    @team += event.code_str
                when "Enter"
                    @state = :auto
                when "Backspace"
                    @team = @team[0...-1]
                end
                draw_box_thing do
                    @win.setpos(2,12)
                    @win.addstr(event.code_str)
                    @win.setpos(4,12)
                    @win.addstr(event.code.to_s)
                    @win.setpos(4,22)
                    @win.addstr(@team)
                end
            when :auto
                draw_box_thing do
                    @data[event.code] ||= 0
                    @data[event.code] += 1
                    @win.setpos(2,12)
                    @win.addstr(event.code_str)
                    @win.setpos(4,12)
                    @win.addstr(event.code.to_s)
                    @win.setpos(4,22)
                    @win.addstr(@data[event.code].to_s)
                    if event.code_str == "Enter"
                        @state = :postmatch
                    end
                end
            when :postmatch
                draw_box_thing do
                    @win.setpos(3, 12)
                    @win.addstr("Saving data to server...")
                end
                uuid = JSON.parse(HTTParty.get('http://vps.boilerinvasion.org:5984/_uuids').body)['uuids'].first
                response = JSON.parse(HTTParty.put('http://vps.boilerinvasion.org:5984/test/' + uuid, body: @data.to_json, headers: {Referer: 'vps.boilerinvasion.org'}).body)
                draw_box_thing do
                    @win.setpos(3, 12)
                    @win.addstr("Data saved!")
                    @win.setpos(4, 12)
                    @win.addstr("Push any key to continue")
                end
                @state = :prestart
            end

        end
        @win.clear
        @win.getch
    end

    def draw_box_thing
        # do initial stuff with @win
        @win.clear
        @win.box 'x', 'x'
        @win.setpos 2,2
        @win.addstr @position
        @win.setpos 3,2
        @win.addstr(@team)
        yield
        # do closing stuff with @win
        @win.refresh
    end

    def safe
        true 
    end

    def data
        @data
    end

    def pos
        @position
    end
    
    def team
        @team.to_i
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

            workers.each do |w|
                print w.pos + ": "
                puts "Team: " + w.team.inspect
                puts w.data.inspect
            end

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
