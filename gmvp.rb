require 'date'
require 'fileutils'
require 'open3'
require 'shellwords'
require 'yaml'

CONFIG = YAML.load_file File.join(__dir__, 'gmvp.yml')
EMAILS = CONFIG[:emails]
BACKUP_PATH = File.expand_path CONFIG[:backup_path]

def dir_for email
  File.join BACKUP_PATH, email.split('@').first
end

def oauth_for email
  File.join File.expand_path('~/.gmvault'), "#{email}.oauth2"
end

def key_for email
  File.join dir_for(email), '.info/.storage_key.sec'
end

def pass_for email
  "gmvault/#{email}"
end

EMAILS.each do |email|
  Open3.popen2("pass #{pass_for(email)}") do |stdin, stdout|
    oauth = stdout.gets.chomp
    key = stdout.gets.chomp

    raise "oauth is empty for email #{email}" if oauth.empty?
    raise "key is empty for email #{email}" if key.empty?

    File.write oauth_for(email), oauth
    File.write key_for(email), key
  end
end

EMAILS.each do |email|
  command = "gmvault sync --type quick --db-dir #{dir_for(email)} --oauth2 --encrypt #{email}"

  Open3.popen2(command) do |stdin, stdout|
    STDOUT.write stdout.read
  end
end

EMAILS.each do |email|
  oauth = File.read oauth_for(email)
  key = File.read key_for(email)

  Open3.popen2("pass insert -f -m #{pass_for(email)}") do |stdin, stdout|
    stdout.gets
    stdin.puts oauth
    stdin.puts key
  end

  File.delete oauth_for(email)
  File.delete key_for(email)
end

Open3.popen2('pass git push') do |stdin, stdout|
  STDOUT.write stdout.read
end
