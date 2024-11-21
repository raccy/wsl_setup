# frozen_string_literal: true

# setup wsl

require "open3"

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
  rakefile: __FILE__,
  work: ".",
  location: "image",
  archive: "distro",
  config: "setup.yml",
  dir: __dir__,
  playbooks: "playbooks",
  proxy: nil,
  http_proxy: ENV.fetch("http_proxy", nil),
  https_proxy: ENV.fetch("http_proxy", nil),
}.to_h do |name, default|
  [name, ENV.fetch("WSL_SETUP_#{name.to_s.upcase}", default)]
end

WSL_SETUP[:name] ||= WSL_SETUP[:distro]

WSL_SETUP[:work] = File.expand_path(WSL_SETUP[:work])
WSL_SETUP[:location] = File.expand_path(WSL_SETUP[:location], WSL_SETUP[:work])
WSL_SETUP[:archive] = File.expand_path(WSL_SETUP[:archive], WSL_SETUP[:work])
WSL_SETUP[:config] = File.expand_path(WSL_SETUP[:config], WSL_SETUP[:work])
WSL_SETUP[:dir] = File.expand_path(WSL_SETUP[:dir])
WSL_SETUP[:playbooks] = File.expand_path(WSL_SETUP[:playbooks], WSL_SETUP[:dir])

if File.extname(WSL_SETUP[:archive]).empty?
  WSL_SETUP[:archive] += case WSL_SETUP[:version]
  in 1 then ".tar"
  in 2 then ".vhdx"
  end
end

WSL_SETUP[:root] = case WSL_SETUP[:version]
in 1 then "#{WSL_SETUP[:location]}/rootfs"
in 2 then "//wsl.localhost/#{WSL_SETUP[:name]}"
end

WSL_SETUP[:location_disk] = case WSL_SETUP[:version]
in 1 then "#{WSL_SETUP[:location]}/rootfs"
in 2 then "#{WSL_SETUP[:location]}/ext4.vhdx"
end

if WSL_SETUP[:proxy]
  %i[http_proxy https_proxy].each do |name|
    WSL_SETUP[name] ||= WSL_SETUP[:proxy]
  end
end

def wsl_run(cmd, binmode: true, capture: false, **opts)
  puts cmd
  wsl_cmd_opts = %i[distro user cd env].to_h { |key| [key, opts.delete(key)] }
  wsl_cmd = generate_wsl_cmd(cmd, **wsl_cmd_opts.compact)

  if capture
    stdout, status = Open3.capture2(wsl_cmd, binmode: binmode, **opts)
    raise "Failed to command in wsl: #{cmd}" unless status.success?

    stdout
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
    .force_encoding(Encoding::UTF_8)
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

def check_path(path)
  return if path =~ %r{\A[\w/.-]+\z}

  raise "invalid path: #{path}"
end

def check_mode(mode)
  return if mode =~ /\A([ugoa]*([-+=]([rwxXst]*|[ugo]))+|[-+=][0-7]+)\z/

  raise "invalid mode: #{mode}"
end

def vhd_option
  if File.extname(WSL_SETUP[:archive]).casecmp?(".vhdx")
    "--vhd"
  else
    ""
  end
end

def proxy_env
  WSL_SETUP.slice(:http_proxy, :https_proxy)
end

task default: :setup

desc "Setup WSL distribution"
task setup: %i[wsl ansible_playbook]

desc "Remove WSL distribution"
task :remove do
  sh "wsl --unregister #{WSL_SETUP[:name]}"
  rm "#{WSL_SETUP[:location_disk]}"
  rmdir "#{WSL_SETUP[:location]}"
end

task wsl: WSL_SETUP[:location_disk]

file WSL_SETUP[:location_disk] => WSL_SETUP[:archive] do |t|
  sh "wsl --import #{WSL_SETUP[:name]} #{WSL_SETUP[:location]} #{t.source} " \
     "--version #{WSL_SETUP[:version]} #{vhd_option}"
end

file WSL_SETUP[:archive] do |t|
  sh "wsl --status" do |_result, status|
    if status.success?
      sh "wsl --update"
    else
      sh "wsl --install --no-distribute" do
        puts "Reboot after 10secs"
        sh "shutdown /r /t 10 /c \"Reboot for wsl installing.\""
        exit
      end
    end
  end
  distro_exe = DISTRO_EXE_MAP.fetch(WSL_SETUP[:distro])
  sh "wsl --install #{WSL_SETUP[:distro]} --no-launch"
  sh "start /wait #{distro_exe} install --root"
  sh "wsl --terminate #{WSL_SETUP[:distro]}"
  sh "wsl --shutdown"
  sh "wsl --export #{WSL_SETUP[:distro]} #{t.name} #{vhd_option}"
  sh "wsl --unregister #{WSL_SETUP[:distro]}"
end

task apt: :wsl

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
  wsl_run("ansible-playbook all.yml #{option}", cd: WSL_SETUP[:playbooks])
end

task ansible_playbook_root: :ansible do
  option = String.new
  if FileTest.file?(WSL_SETUP[:config])
    option << " -e @#{wsl_path(WSL_SETUP[:config], user: 'root')}"
  end
  wsl_run("ansible-playbook root.yml #{option}", cd: WSL_SETUP[:playbooks],
    user: "root")
  sh "wsl --terminate #{WSL_SETUP[:name]}"
end

task ansible: %i[apt update] do
  wsl_run("apt install ansible -y", env: proxy_env, user: "root")
end
