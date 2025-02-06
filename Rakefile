# frozen_string_literal: true

# setup wsl

require "open3"
require "yaml"
require "win32/registry"

WSL_SETUP = {
  name: nil,
  distro: "Ubuntu",
  version: 2,
  input_user: false,
  require_password: false,
  work: ".",
  location: "image",
  config: "wsl_setup.yml",
  dir: __dir__,
  playbooks: "playbooks",
  proxy: nil,
  http_proxy: ENV.fetch("http_proxy", nil),
  https_proxy: ENV.fetch("http_proxy", nil),
  skip_location: false,
  skip_update: false,
}.to_h do |name, default|
  [name, ENV.fetch("WSL_SETUP_#{name.to_s.upcase}", default)]
end

WSL_SETUP_CONFIG_FILE = File.expand_path(WSL_SETUP[:config], WSL_SETUP[:work])
if FileTest.exist?(WSL_SETUP_CONFIG_FILE)
  WSL_SETUP.merge!(YAML.load_file(WSL_SETUP_CONFIG_FILE, symbolize_names: true)
    .fetch(:wsl_setup, {}))
end

WSL_SETUP[:name] ||= WSL_SETUP[:distro]
WSL_SETUP[:version] = WSL_SETUP[:version].to_i
WSL_SETUP[:root] = "//wsl.localhost/#{WSL_SETUP[:name]}"

WSL_SETUP[:work] = File.expand_path(WSL_SETUP[:work])
WSL_SETUP[:location] = File.expand_path(WSL_SETUP[:location], WSL_SETUP[:work])
WSL_SETUP[:config] = File.expand_path(WSL_SETUP[:config], WSL_SETUP[:work])
WSL_SETUP[:dir] = File.expand_path(WSL_SETUP[:dir])
WSL_SETUP[:playbooks] = File.expand_path(WSL_SETUP[:playbooks], WSL_SETUP[:dir])

WSL_SETUP[:location_disk] = case WSL_SETUP[:version]
in 1 then "#{WSL_SETUP[:location]}/rootfs"
in 2 then "#{WSL_SETUP[:location]}/ext4.vhdx"
end

if WSL_SETUP[:proxy]
  %i[http_proxy https_proxy].each do |name|
    WSL_SETUP[name] ||= WSL_SETUP[:proxy]
  end
end

def run_capture(cmd, encoding: Encoding::UTF_8, exception: false, **opts)
  stdout, status = Open3.capture2(cmd, binmode: true, **opts)
  if status.success?
    stdout.encode(Encoding.default_internal || Encoding::UTF_8, encoding)
      .gsub(/\R/, "\n")
  elsif exception
    raise "Failed to command: #{cmd}"
  end
end

def wsl_run(cmd, capture: false, **opts)
  puts cmd
  wsl_cmd_opts = %i[distro user cd env].to_h { |key| [key, opts.delete(key)] }
  wsl_cmd = generate_wsl_cmd(cmd, **wsl_cmd_opts.compact)

  if capture
    run_capture(wsl_cmd, exception: true, **opts)
  else
    system(wsl_cmd, **opts, exception: true)
  end
end

# rubocop: disable Naming/MethodParameterName
def generate_wsl_cmd(cmd, distro: WSL_SETUP[:name], user: nil, cd: nil, env: {})
  wsl_cmd = "wsl -d #{distro}"
  wsl_cmd << " -u #{user}" if user
  wsl_cmd << " --cd \"#{cd}\"" if cd
  wsl_cmd << " -- "
  env.each { |key, value| wsl_cmd << "#{key}=#{value} " }
  wsl_cmd << cmd
end
# rubocop: enable Naming/MethodParameterName

def wsl_path(path, **opts)
  wsl_run("wslpath -u \"#{path}\"", capture: true, **opts)
    .force_encoding(Encoding::UTF_8).chomp
end

def wsl_file_read(path, **opts)
  check_path(path)
  wsl_run("cat -- #{path}", capture: true, **opts)
end

def wsl_file_write(path, data, mode: nil, **opts)
  check_path(path)
  wsl_mkdir(File.dirname(path), **opts)
  wsl_run("tee -- #{path}", capture: true, stdin_data: data, **opts)
  wsl_chmod(path, mode) if mode
end

def wsl_file_append(path, data, mode: nil, **opts)
  check_path(path)
  wsl_mkdir(File.dirname(path), **opts)
  wsl_run("tee -a -- #{path}", capture: true, stdin_data: data, **opts)
  wsl_chmod(path, mode) if mode
end

def wsl_mkdir(path, mode: nil, **opts)
  check_path(path)
  wsl_run("mkdir -p -- #{path}", **opts)
  wsl_chmod(path, mode) if mode
end

def wsl_chmod(path, mode)
  check_path(path)
  check_mode(mode)
  wsl_run("chmod #{mode} -- #{path}")
end

def wsl_whoami(**opts)
  wsl_run("whoami", capture: true, **opts).force_encoding(Encoding::UTF_8).chomp
end

def check_path(path)
  return if path =~ %r{\A[\w/.-]+\z}

  raise "invalid path: #{path}"
end

def check_mode(mode)
  return if mode =~ /\A([ugoa]*([-+=]([rwxXst]*|[ugo]))+|[-+=][0-7]+)\z/

  raise "invalid mode: #{mode}"
end

def proxy_env
  WSL_SETUP.slice(:http_proxy, :https_proxy)
end

def get_wsl_status # rubocop: disable Naming/AccessorMethodName
  result = run_capture("wsl --status", encoding: Encoding::UTF_16LE)
  return if result.nil?

  {
    default: /^既定のディストリビューション: (\S+)$/.match(result)&.[](1),
    version: /^既定のバージョン: (\S+)$/.match(result)[1].to_i,
    enable_wsl1: !/^WSL1 は、現在のマシン構成ではサポートされていません。$/
      .match?(result),
  }
end

def get_wsl_list # rubocop: disable Naming/AccessorMethodName
  result = run_capture("wsl --list --all --verbose",
    encoding: Encoding::UTF_16LE)
  return {} if result.nil?

  parse_wsl_list(result).to_h { |d| [d[:name], d] }
end

def parse_wsl_list(list)
  list.lines.drop(1).map do |line|
    if (m = /^(.)\s+(\S+)\s+(\S+)\s+(\d)\s*$/.match(line))
      { default: m[1] == "*", name: m[2], state: m[3], version: m[4].to_i }
    else
      raise "invalid wsl list line: #{line}"
    end
  end
end

def get_wsl_registry # rubocop: disable Naming/AccessorMethodName
  list = {}
  open_lxss_registry do |reg|
    reg.each_key do |key, _wtime|
      reg.open(key) do |sub|
        list[sub["DistributionName"]] =
          { key: key, uid: sub["DefaultUid"], path: sub["BasePath"] }
      end
    end
  end
  list
end

def open_lxss_registry(subkey = nil, mode: "r", &block)
  key = 'Software\Microsoft\Windows\CurrentVersion\Lxss'
  key += "\\#{subkey}" if subkey
  desired = calc_mask(mode)
  Win32::Registry::HKEY_CURRENT_USER.open(key, desired, &block)
end

def calc_mask(mode)
  desired = 0
  desired |= Win32::Registry::KEY_READ if mode.include?("r")
  desired |= Win32::Registry::KEY_WRITE if mode.include?("w")
  desired |= Win32::Registry::KEY_EXECUTE if mode.include?("x")
  desired
end

task default: :create

desc "Create WSL distribution"
task create: %i[distro ansible_playbook]

desc "Destroy WSL distribution"
task :destroy do
  if get_wsl_list.key?(WSL_SETUP[:name])
    sh "wsl --unregister #{WSL_SETUP[:name]}"
    rmdir WSL_SETUP[:location] unless WSL_SETUP[:skip_location]
  end
end

task :wsl do
  wsl_status = get_wsl_status
  if wsl_status.nil?
    # install wsl
    sh "wsl --install --no-distribution"
    puts "Reboot after 10secs"
    sh "shutdown /r /t 10 /c \"Reboot for wsl installing.\""
    exit # no return
  elsif WSL_SETUP[:version] == 1 && !wsl_status[:enable_wsl1]
    # NOTE: 下記コマンドでは有効にならない
    #   wsl --install --enable-wsl1 --no-distribution
    # install Microsoft-Windows-Subsystem-Linux feature
    # TODO: 管理者権限がないため、下記は
    # sh "dism /online /enable-feature " \
    #    "/featurename:Microsoft-Windows-Subsystem-Linux /all /norestart"
    # puts "Reboot after 10secs"
    # sh "shutdown /r /t 10 /c \"Reboot for fuature installing for wsl1.\""
    puts "WSL1 を使用するには、\"Linux 用 Windows サブシステム\" オプション " \
      "コンポーネントを有効にしてください。"
    exit # no return
  end
end

task distro: :wsl do
  unless get_wsl_list.key?(WSL_SETUP[:name])
    install_option = String.new
    install_option << " --install #{WSL_SETUP[:distro]}"
    unless WSL_SETUP[:skip_location]
      install_option << " --location #{WSL_SETUP[:location_disk]}"
    end
    if WSL_SETUP[:name] != WSL_SETUP[:distro]
      install_option << " --name #{WSL_SETUP[:name]}"
    end
    install_option << " --no-launch"
    install_option << " --version #{WSL_SETUP[:version]}"
    sh "wsl #{install_option}"
    if WSL_SETUP[:input_user]
      sh "wsl --distribution #{WSL_SETUP[:name]}"
    else
      key = get_wsl_registry[WSL_SETUP[:name]][:key]
      open_lxss_registry(key, "w") do |reg|
        reg["RunOOBE"] = 0
      end
    end
  end
end

task apt: :distro

desc "Update WSL distribution"
task update: :apt do
  unless WSL_SETUP[:skip_update]
    wsl_run("apt update -y", env: proxy_env, user: "root")
    wsl_run("apt upgrade -y", env: proxy_env, user: "root")
    wsl_run("apt autoremove -y", env: proxy_env, user: "root")
  end
end

task ansible_playbook: %i[ansible ansible_playbook_root] do
  option = String.new
  if FileTest.file?(WSL_SETUP[:config])
    option << " -e @#{wsl_path(WSL_SETUP[:config])}"
  end
  option << " -e user_default=#{wsl_whoami}" if WSL_SETUP[:input_user]
  option << " -K" if WSL_SETUP[:require_password]
  wsl_run("ansible-playbook all.yml #{option}", cd: WSL_SETUP[:playbooks])
end

task ansible_playbook_root: :ansible do
  option = String.new
  if FileTest.file?(WSL_SETUP[:config])
    option << " -e @#{wsl_path(WSL_SETUP[:config], user: 'root')}"
  end
  option << " -e user_default=#{wsl_whoami}" if WSL_SETUP[:input_user]

  wsl_run("ansible-playbook root.yml #{option}", cd: WSL_SETUP[:playbooks],
    user: "root")
  sh "wsl --terminate #{WSL_SETUP[:name]}"
end

task ansible: %i[apt update].compact do
  wsl_run("apt install ansible -y", env: proxy_env, user: "root")
end
