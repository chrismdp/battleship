$:.unshift File.expand_path("../../lib", __FILE__)
require "battleship/game"
require "battleship/console_renderer"
require "battleship/util"
require "stringio"
require "digest/sha1"
require "forwardable"
require "drb"

DELAY = 0.2
PORT = 4432

class PlayerClient
  extend Forwardable

  def initialize(secret, object)
    @secret = secret
    @object = object
  end

  def method_missing(m, *args)
    args.unshift(@secret)
    @object.__send__(m, *args)
  end

  def kill
    @object.stop(@secret)
  end
end

begin
  start_time = Time.now
  DRb.start_service

  player_server = File.expand_path("../player_server.rb", __FILE__)

  players = []

  2.times.each do |i|
    path = ARGV[i]
    port = PORT + i
    secret = Digest::SHA1.hexdigest("#{Time.now}#{rand}#{i}")
    cmd = %{bundle exec ruby #{player_server} "#{path}" #{port} #{secret} &}
    puts cmd
    system cmd
    Battleship::Util.wait_for_socket('0.0.0.0', port)
    players << PlayerClient.new(secret, DRbObject.new(nil, "druby://0.0.0.0:#{port}"))
  end

  winners = []

  starting_time = Time.now - start_time

  start_time = Time.now

  1.times do |i|
    stderr = ""
    $stderr = StringIO.new(stderr)

    game = Battleship::Game.new(10, [2, 3, 3, 4, 5], *players)
    50.times do
      game.tick
      $stdout << "."
    end
    $stdout << "\n"
  end

  time_taken = Time.now - start_time

  puts
  winners.each_with_index do |name, i|
    puts "Round #{i+1}. #{name}"
  end

  puts "START TIME: #{starting_time}"
  puts "TIME TAKEN: #{time_taken}"

  players.each &:kill

rescue Exception => e
  $stderr = STDERR
  puts e.inspect
  puts e.backtrace
  raise e
ensure
  players.each &:kill
end
