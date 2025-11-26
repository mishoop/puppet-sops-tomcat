# Custom Hiera backend for SOPS encrypted files
# Supports age encryption backend

require 'json'
require 'yaml'
require 'open3'

Puppet::Functions.create_function(:sops_lookup_key) do
  dispatch :sops_lookup_key do
    param 'String', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def sops_lookup_key(key, options, context)
    return context.cached_value(key) if context.cache_has_key(key)

    # Get options
    sops_path = options['sops_path'] || '/usr/local/bin/sops'
    age_key_file = options['age_key_file']
    datadir = options['datadir'] || context.interpolate('%{environment}/hieradata')

    # Handle paths
    paths = options['paths'] || []
    paths = [paths] unless paths.is_a?(Array)

    paths.each do |path|
      interpolated_path = context.interpolate(path)
      full_path = File.join(Puppet.settings[:environmentpath], datadir, interpolated_path)

      next unless File.exist?(full_path)

      begin
        data = decrypt_sops_file(full_path, sops_path, age_key_file)

        if data.is_a?(Hash) && data.key?(key)
          context.cache(key, data[key])
          return data[key]
        end
      rescue => e
        context.explain { "SOPS decryption failed for #{full_path}: #{e.message}" }
        next
      end
    end

    context.not_found
  end

  def decrypt_sops_file(path, sops_path, age_key_file)
    env = {}
    env['SOPS_AGE_KEY_FILE'] = age_key_file if age_key_file && File.exist?(age_key_file)

    cmd = [sops_path, '--decrypt', path]

    stdout, stderr, status = Open3.capture3(env, *cmd)

    unless status.success?
      raise Puppet::Error, "SOPS decrypt failed: #{stderr}"
    end

    # Parse based on file extension
    if path.end_with?('.json')
      JSON.parse(stdout)
    else
      YAML.safe_load(stdout, permitted_classes: [Symbol, Date, Time])
    end
  end
end
