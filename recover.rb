require "bundler/setup"
require "bitcoin"
require "shamir-secret-sharing"
require 'open3'

needed = ARGV[0] ? ARGV[0].to_i : 3
scanned = []

Open3.popen2("zbarcam --nodisplay /dev/video1"){|i,o,t|
  pid = t.pid

  puts "please scan #{needed} qrcodes to recover the private key"
  while scanned.size != needed
    line = o.gets
    unless scanned.include?(line)
      part = line.split(":").last.chomp
      scanned << part
      puts "new part: #{line}"

      unless scanned.size == needed
        puts "please scan #{needed-scanned.size} more qrcodes"
      else
        puts "all parts scanned"
        p priv = ShamirSecretSharing::Base58.combine( scanned )
        key = Bitcoin::Key.from_base58(priv)
        puts "recovered address: #{key.addr}"
        puts "recovered privkey: #{key.to_base58}"
      end
    end
  end

  i.close
  Process.kill("USR1", t.pid)
}
