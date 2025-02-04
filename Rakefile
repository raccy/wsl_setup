# frozen_string_literal: true

# setup wsl

require "open3"
require "yaml"
require "win32/registry"

DISTRO_EXE_MAP = {
  "AlmaLinux-8" => "almalinux8.exe",
  "AlmaLinux-9" => "almalinux9.exe",
  "Debian" => "debian.exe",
  "OracleLinux_7_9" => "OracleLinux79.exe",
  "OracleLinux_8_7" => "OracleLinux87.exe",
  "OracleLinux_9_1" => "OracleLinux91.exe",
  "SUSE-Linux-Enterprise-15-SP5" => "SUSE-Linux-Enterprise-15-SP5.exe",
  "SUSE-Linux-Enterprise-15-SP6" => "SUSE-Linux-Enterprise-15-SP6.exe",
  "Ubuntu" => "ubuntu.exe",
  "Ubuntu-18.04" => "ubuntu1804.exe",
  "Ubuntu-20.04" => "ubuntu2004.exe",
  "Ubuntu-22.04" => "ubuntu2204.exe",
  "Ubuntu-24.04" => "ubuntu2404.exe",
  "kali-linux" => "kali.exe",
  "openSUSE-Leap-15.6" => "openSUSE-Leap-15.6.exe",
  "openSUSE-Tumbleweed" => "openSUSE-Tumbleweed.exe",
}.freeze

WSL_SETUP = {
  name: nil,
  distro: "Ubuntu",
  version: 2,
  input_user: false,
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

def wsl_status
  result = run_capture("wsl --status", encoding: Encoding::UTF_16LE)
  return if result.nil?

  {
    default: /^既定のディストリビューション: (\S+)$/.match(result)&.[](1),
    version: /^既定のバージョン: (\S+)$/.match(result)[1].to_i,
    enable_wsl1: !/^WSL1 は、現在のマシン構成ではサポートされていません。$/
      .match?(result),
  }
end

def wsl_list
  result = run_capture("wsl --list --all --verbose",
    encoding: Encoding::UTF_16LE)
  return {} if result.nil?

  list = result.lines.drop(1)&.to_h do |line|
    if (m = /^(.)\s+(\S+)\s+(\S+)\s+(\d)\s*$/.match(line))
      [m[2], {
        default: m[1] == "*",
        name: m[2],
        state: m[3],
        version: m[4].to_i,
      }]
    else
      raise "invalid wsl list line: #{line}"
    end
  end

  Win32::Registry::HKEY_CURRENT_USER
    .open('Software\Microsoft\Windows\CurrentVersion\Lxss') do |reg|
    reg.each_key do |key, wtime|
      reg.open(key) do |sub|
        name = sub["DistributionName"]
        list[name][:key] = key
        list[name][:uid] = sub["DefaultUid"]
        list[name][:path] = sub["BasePath"]
      end
    end
  end

  list
end

task default: :create

desc "Create WSL distribution"
task create: %i[distro ansible_playbook]

desc "Destroy WSL distribution"
task :destroy do
  if wsl_list.key?(WSL_SETUP[:name])
    sh "wsl --unregister #{WSL_SETUP[:name]}"
    unless WSL_SETUP[:skip_location]
      rmdir WSL_SETUP[:location]
    end
  end
end

task distro: (WSL_SETUP[:skip_location] ? :install_distro
                                        : WSL_SETUP[:location_disk])

task :install_wsl do
  # install wsl
  sh "wsl --install --no-distribute"
  puts "Reboot after 10secs"
  sh "shutdown /r /t 10 /c \"Reboot for wsl installing.\""
  exit # no return
end

task :install_feature do
  # install Microsoft-Windows-Subsystem-Linux feature
  sh "dism /online /enable-feature " \
     "/featurename:Microsoft-Windows-Subsystem-Linux /all /norestart"
  puts "Reboot after 10secs"
  sh "shutdown /r /t 10 /c \"Reboot for fuature installing for wsl1.\""
  exit # no return
end

task :update_wsl do
  sh "wsl --update"
end

task :install_distro do
  wsl = wsl_status
  task_name =
    if wsl.nil?
      "install_wsl"
    elsif WSL_SETUP[:version] == 1 && !wsl[:enable_wsl1]
      "install_feature"
    else
      "update_wsl"
    end
  Rake::Task[task_name].invoke

  unless wsl_list.key?(WSL_SETUP[:distro])
    if WSL_SETUP[:input_user]
      sh "wsl --install #{WSL_SETUP[:distro]}"
    else
      distro_exe = DISTRO_EXE_MAP.fetch(WSL_SETUP[:distro])
      sh "wsl --install #{WSL_SETUP[:distro]} --no-launch"
      sh "start /wait #{distro_exe} install --root"
    end
  end
end

file WSL_SETUP[:location_disk] do
  Rake::Task[:install_distro].invoke
  sh "wsl --terminate #{WSL_SETUP[:distro]}"
  sh "wsl --shutdown"
  if WSL_SETUP[:name] == WSL_SETUP[:distro]
    sh "wsl --manage #{WSL_SETUP[:distro]} --move #{WSL_SETUP[:location]}"
    if wsl_list[WSL_SETUP[:name]][:version] != WSL_SETUP[:version]
      sh "wsl --set-version #{WSL_SETUP[:distro]} #{WSL_SETUP[:version]}"
    end
  else
    if WSL_SETUP[:version] == 1
    sh "wsl --export #{WSL_SETUP[:distro]} - |" \
       "wsl --import #{WSL_SETUP[:name]} #{WSL_SETUP[:location]} - " \
       "--version #{WSL_SETUP[:version]}"
    else
      sh "wsl --export #{WSL_SETUP[:distro]} - --vhd |" \
      "wsl --import #{WSL_SETUP[:name]} #{WSL_SETUP[:location]} - " \
      "--version #{WSL_SETUP[:version]} --vhd"
    end
    list = wsl_list
    default_uid = list[WSL_SETUP[:distro]][:uid]
    Win32::Registry::HKEY_CURRENT_USER
      .open('Software\Microsoft\Windows\CurrentVersion\Lxss') do |reg|
      reg.open(list[WSL_SETUP[:name]][:key],
        Win32::Registry::KEY_READ | Win32::Registry::KEY_WRITE) do |sub|
        sub["DefaultUid"] = default_uid
      end
    end
    sh "wsl --unregister #{WSL_SETUP[:distro]}"
  end
end

task apt: :distro

desc "Update WSL distribution"
task update: :apt do
  wsl_run("apt update -y", env: proxy_env, user: "root")
  wsl_run("apt upgrade -y", env: proxy_env, user: "root")
  wsl_run("apt autoremove -y", env: proxy_env, user: "root")
end

task ansible_playbook: %i[ansible ansible_playbook_root] do
  option = String.new
  if FileTest.file?(WSL_SETUP[:config])
    option << " -e @#{wsl_path(WSL_SETUP[:config])}"
  end
  if WSL_SETUP[:input_user]
    option << " -e user_default=#{wsl_whoami} -K"
  end
  wsl_run("ansible-playbook all.yml #{option}", cd: WSL_SETUP[:playbooks])
end

task ansible_playbook_root: :ansible do
  option = String.new
  if FileTest.file?(WSL_SETUP[:config])
    option << " -e @#{wsl_path(WSL_SETUP[:config], user: 'root')}"
  end
  if WSL_SETUP[:input_user]
    option << " -e user_default=#{wsl_whoami}"
  end

  wsl_run("ansible-playbook root.yml #{option}", cd: WSL_SETUP[:playbooks],
    user: "root")
  sh "wsl --terminate #{WSL_SETUP[:name]}"
end

task ansible: [:apt, (:update unless WSL_SETUP[:skip_update])].compact do
  wsl_run("apt install ansible -y", env: proxy_env, user: "root")
end
