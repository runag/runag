lines = STDIN.each_line.to_a

last_auth = lines.rindex{|line| line =~ /^auth/ }

if last_auth.nil?
  raise "Unable to find any auth lines"
end

lines[0..last_auth].each {|line| puts line }

puts "auth       optional   pam_gnome_keyring.so"

after_auth = lines[last_auth+1..-1]

last_session = after_auth.rindex{|line| line =~ /^session/ }

if last_session.nil?
  raise "Unable to find any session lines"
end

after_auth[0..last_session].each {|line| puts line }

puts "session    optional   pam_gnome_keyring.so auto_start"

after_auth[last_session+1..-1].each {|line| puts line }
