require 'hoist/version'
require 'hoist/filters/base64'
require 'hoist/colorize'

require 'liquid'
require 'yaml'
require 'openssl'
require 'open3'

# Main Module for Hoist
module Hoist

  # Defaults
  @settings_file = 'settings.yml'
  @settings_file_encrypted = 'settings.eyml'
  @key_file = File.expand_path('~/.ssh/id_rsa')
  @local_key_file = 'key.pem'

  # Register Additional filters
  Liquid::Template.register_filter(Hoist::AdditionalFilters)

  def self.cmd_render(args, options)
    begin
      #Set defaults
      set_defaults(options)

      # Read config file
      config = env_from_config(options)


      output = StringIO.new
      args.each do |arg|
        recursively_parse_and_render(arg, config, output)
      end
      puts output.string
    rescue Exception => e
      STDERR.puts "ERROR #{e}".red()
      exit 1
    end
  end

  def self.cmd_apply(args, options)
    begin
      # Set defaults
      set_defaults(options)

      # Read config file
      config = env_from_config(options)

      output = StringIO.new
      args.each do |arg|
        recursively_parse_and_render(arg, config, output)
      end
      Open3.popen3('kubectl apply -f -') do |i,o,e,t|
        i.write output.string
        i.close
        puts o.read
      end
    rescue Exception => e
      STDERR.puts "ERROR #{e}".red()
      exit 1
    end
  end

  def self.cmd_delete(args, options)
    begin
      # Set defaults
      set_defaults(options)

      # Read config file
      config = env_from_config(options)

      output = StringIO.new
      args.each do |arg|
        recursively_parse_and_render(arg, config, output)
      end
      Open3.popen3('kubectl delete -f -') do |i,o,e,t|
        i.write output.string
        i.close
        puts o.read
      end
    rescue Exception => e
      STDERR.puts "ERROR #{e}".red()
      exit 1
    end
  end

  def self.cmd_encrypt(args, options)
    begin
      # Set defaults
      set_defaults(options)
      config_file_content = File.read(options.config)
      encrypted = encrypt_config(config_file_content, options.key, options.passphrase)
      marshal_to_file(args, encrypted)
    rescue Exception => e
      STDERR.puts "ERROR #{e}".red()
      exit 1
    end
  end

  def self.cmd_decrypt(args, options)
    begin
      # Set defaults
      set_defaults(options)

      config_file_content = Marshal.load(File.binread(options.config))
      plaintext = decrypt_config(config_file_content, options.key, options.passphrase)
      write_to_file_or_stdout(args, plaintext)
    rescue Exception => e
      STDERR.puts "ERROR #{e}".red()
      exit 1
    end
  end

  # HELPER METHODS
  def self.env_from_config(options)
    config_uri = options.config
    env = case
      when config_uri.end_with?('.yml')
        YAML.load_file(config_uri)
      when config_uri.end_with?('.eyml')
        config_file_content = Marshal.load(File.binread(config_uri))
        env_str = decrypt_config(config_file_content, options.key, options.passphrase)
        YAML.load(env_str)
      else
        {}
      end

    return env
  end

  def self.set_defaults(options)
    # If no -c or --config options was specified, set a default
    # An ecrypted settings file takes precendece over an unencrypted settings file.
    unless options.config
      if File.exists?(@settings_file_encrypted)
        options.config = @settings_file_encrypted
      else
        options.config = @settings_file
      end
    end

    # If no -k or --key options was specified, set a default
    # A key.pem file in the current directory takes precedence
    # over the default Linux key location .
    unless options.key
      if File.exists?(@local_key_file)
        options.key = @local_key_file
      else
        options.key = @key_file
      end
    end
  end

  def self.encrypt_config(config, key_file, passphrase)
    rsa_key = OpenSSL::PKey::RSA.new(File.read(key_file), passphrase)
    # Split into 64 character chunks
    chunks = config.scan(/.{1,64}/m)
    out = []
    chunks.each do |chunk|
      c = rsa_key.public_encrypt(chunk)
      c64 = Base64.strict_encode64(c)
      out << c64
    end
    out
  end

  def self.decrypt_config(encrypted_config, key_file, passphrase)
    rsa_key = rsa_key = OpenSSL::PKey::RSA.new(File.read(key_file), passphrase)
    out = []
    encrypted_config.each do |chunk|
      cp = Base64.decode64(chunk)
      m = rsa_key.private_decrypt(cp)
      out << m
    end
    out.join("")
  end

  def self.write_to_file_or_stdout(args, content)
    case args.count
    when 0
      puts content
    else
      File.write(args[0], content)
    end
  end

  def self.marshal_to_file(args, content)
    case args.count
    when 0
      puts Base64.encode64(content)
    else
      File.open(args[0], 'wb') {|f| f.write(Marshal.dump(content))}
    end
  end

  # Parse a template and render using the given environment
  # In case of errors, fail and print error details
  def self.parse_and_render(file, env, out)
   begin
     template = Liquid::Template.parse(File.read(file), line_numbers: true)
     rendered = template.render!(env, strict_variables: true)
     out.puts rendered
   rescue Liquid::UndefinedVariable => e
     STDERR.puts "ERROR in #{file}: #{e}".red()
     exit 1
   end
  end

  def self.recursively_parse_and_render(path, config, output)
    if File.directory?(path)
      # Render all template files recursively
      Dir.glob("#{path}/**/*").each do |file|
        parse_and_render(file, config, output) unless File.directory?(file)
      end
    else
      parse_and_render(path, config, output)
    end
  end

end
