class OpenBeken < Oxidized::Model
  
  require 'json'
  require 'base64'
  require 'uri'
  require 'net/http'


  # --- CONFIG ---
  cfg :http do
    # Username and Password if provided
    u = @node.auth[:username].to_s.strip
    p = @node.auth[:password].to_s.strip

    @username = (u && !u.empty?) ? u : "admin"
    @password = (p && !p.empty?) ? p : nil
    
    login_style :basic if @password
  end

  # --- PINS Helper ---
  def get_pin_alias(index)
    case index
    when 23 then "ADC3"
    when 26 then "PWM5"
    when 24 then "PWM4"
    when 6  then "PWM0"
    when 7  then "PWM1"
    when 0  then "TXD2"
    when 1  then "RXD2"
    when 9  then "PWM3"
    when 8  then "PWM2"
    when 10 then "RXD1"
    when 11 then "TXD1"
    else "P#{index}"
    end
  end

  # Getting PINS Configuration
  cmd '/api/pins' do |cfg|
    Oxidized.logger.debug "OpenBeken: Getting Pins configuration on #{@node.name}"
    out = []
    out << "! OPENBEKEN CONFIGURATION BACKUP"
    out << "! Source: #{@node.name}"
    out << "!"
    out << "! --- BEGIN PIN JSON CONFIGURATION ---"

    begin
      data = JSON.parse(cfg)
      
      rolenames = data['rolenames']
      roles     = data['roles']
      channels  = data['channels']
      channels2 = data['channels2'] # Null for not button
      
      pin_config = []

      # Iteriamo su tutti i ruoli
      roles.each_with_index do |role_id, index|
        # Only defined Pins (role != 0)
        next if role_id == 0

        pin_obj = {
          'pin'      => index,
          'alias'    => get_pin_alias(index),
          'role'     => rolenames[role_id].strip,
          'channel'  => channels[index]
        }

        # Gestione pulsanti (Channel 2)
        if channels2 && channels2[index] && channels2[index] != 0
          pin_obj['channel2'] = channels2[index]
        end

        pin_config << pin_obj
      end

      out << JSON.pretty_generate(pin_config)

    rescue => e
      out << "! Error parsing PINs: #{e.message}"
      out << "! Raw data: #{cfg}"
    end

    out << "! --- END JSON CONFIGURATION ---"
    out << "!"
    out.join("\n")
  end

  # Filesystem, (LFS)
  cmd '/api/lfs/' do |cfg|
    out = []
    
    Oxidized.logger.debug "OpenBeken: Starting LFS Filesystem download on #{@node.name}"
    begin
      json_data = JSON.parse(cfg)
      if json_data && json_data['content'].is_a?(Array)
        json_data['content'].each do |f|
          # skipping type 2
          next if f['type'] == 2
          
          fname = f['name']
          out << "! --- BEGIN FILE >#{fname}< ---"
          # dowloading file
          begin
             safe_fname = URI.encode_www_form_component(fname)
             uri = URI.parse("http://#{@node.ip}/api/lfs/#{safe_fname}")
             req = Net::HTTP::Get.new(uri)
             if @password
               req.basic_auth(@username, @password)
             end
             # Requesting file
             res = Net::HTTP.start(uri.hostname, uri.port, :open_timeout => 5, :read_timeout => 10) do |http|
               http.request(req)
             end

             if res.is_a?(Net::HTTPSuccess)
               Oxidized.logger.debug "OpenBeken: LFS file #{fname} sucessful downloaded"
               out << res.body
             else
               Oxidized.logger.error "OpenBeken: HTTP Error #{res.code} dowloading file #{fname}"
               out << "! Error downloading file #{fname}: HTTP #{res.code}"
             end
          rescue => e
            Oxidized.logger.error "OpenBeken: Error #{e.message} downloading file #{fname}"
            out << "! Error downloading file #{fname}: #{e.message}"
          end
          out << "! --- END FILE ---"
          out << "!"
        end

      else
        Oxidized.logger.warning "OpenBeken: Warning no 'content' key in LFS JSON response"
        out << "! No 'content' key found in JSON response."
      end

    rescue => e
      Oxidized.logger.error "OpenBeken: Error parsing LFS JSON #{e.message}"
      out << "! Error parsing LFS JSON: #{e.message}"
    end
    
    out.join("\n")
  end

  # Bynary Dump
  cmd '/api/flash/1e1000-1000' do |cfg|
    Oxidized.logger.debug "OpenBeken: Starting OBK Configuration file download on #{@node.name}"
    out = []
    out << "! --- BEGIN BINARY OBK DUMP (Base64 Encoded) ---"
    out << "! To restore: save block to file, run: grep '^!B64: ' file | sed 's/^!B64: //' | base64 -d > restore.bin"
    out << "!"
    
    if cfg && !cfg.empty?
      b64 = Base64.encode64(cfg)
      b64.each_line do |line|
        out << "!B64: #{line.strip}"
      end
    else
      Oxidized.logger.error "OpenBeken: Error OBK Configuration file is empty or download failed"
      out << "! ERROR: Binary dump empty or download failed."
    end
    
    out << "! --- END BINARY DUMP ---"
    out.join("\n")
  end
end
