require 'tempfile'
require 'base64'

class Tasmota < Oxidized::Model

  # helpers
  def decoder
    vars(:tasmota_decoder) || "/usr/bin/decode-config.py"
  end

  def auth_string
    pass = @node.auth[:password]
    (pass.nil? || pass.to_s.empty?) ? "" : "-p '#{pass}'"
  end

  cmd "true" do
    Oxidized.logger.debug "Tasmota: Starting Backup process for #{@node.name}"
    json_output = ""
    binary_b64 = ""
    # Using temporary file to store Binary Configuration
    Tempfile.create(["tasmota_#{@node.name}", ".dmp"]) do |temp_file|
      temp_path = temp_file.path
      
      # We can close the temporary file handler
      temp_file.close

      # Download and parse commands
      cmd_download = "python3 #{decoder} -e -s #{@node.ip} #{auth_string} -o #{temp_path} -t dmp"
      cmd_parse    = "python3 #{decoder} -s #{temp_path} -t json --json-indent 2 --json-compact --json-show-pw" 

      # File download
      unless system("#{cmd_download} > /dev/null 2>&1")
        raise "Tasmota Error: Failed to download dump on #{temp_path} from #{@node.name}"
      end
      #Oxidized.logger.debug "Tasmota: Dump file #{temp_path} downloaded from #{@node.name}"

      # File parsing
      json_output = `#{cmd_parse} 2>&1`
      # Converting binary file in base64
      raw_content = File.binread(temp_path)
      binary_b64 = Base64.encode64(raw_content)
    end  # Here temporary file is automatically is deleted

    raise "Tasmota Error: Empty JSON received" if json_output.strip.empty?
    Oxidized.logger.debug "Tasmota: End Backup process for #{@node.name}"

    # Creating headers and standar configuration
    [
      "! TASMOTA CONFIGURATION BACKUP",
      "! Source: #{@node.name}",
      "!",
      "! --- BEGIN JSON CONFIGURATION ---",
      json_output.strip,
      "! --- END JSON CONFIGURATION ---",
      "!",
      "! --- BEGIN BINARY DUMP (Base64 Encoded) ---",
      "! To restore: save the block below to a file and run:",
      "! grep '^!B64: ' backup_test.txt | sed 's/^!B64: //' | base64 -d > restore.dmp",
      "!",
      binary_b64.lines.map { |l| "!B64: #{l}" }.join.strip,
      "! --- END BINARY DUMP ---"
    ].join("\n")
  end

  cfg :exec do
    nil
  end

end
