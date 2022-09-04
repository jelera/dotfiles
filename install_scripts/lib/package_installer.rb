# frozen_string_literal: true

class PackageInstaller
  include Helpers::OS

  def self.run(ubuntu: [], fedora: [], mac_os: [])
    new(ubuntu:, fedora:, mac_os:).run
  end

  def initialize(ubuntu:, fedora:, mac_os:)
    @ubuntu = ubuntu
    @fedora = fedora
    @mac_os = mac_os
  end

  def run
    system("#{install_cmd} #{packages}") unless packages.empty?
  end

  private

  def install_cmd
    if mac_os?
      'brew install'
    elsif ubuntu?
      'sudo apt install -y'
    elsif fedora?
      'sudo dnf install -y'
    else
      warn 'cannot run external command'
    end
  end

  def packages
    return @packages if instance_variable_defined?(:@packages)

    raise ArgumentError.new('No packages was received') if no_packages_received?


    pkgs = if mac_os? && !@mac_os.empty?
             @mac_os
           elsif ubuntu? && !@ubuntu.empty?
             @ubuntu
           elsif fedora? && !@fedora.empty?
             @fedora
           else
             ''
           end

    @packages = if pkgs.is_a? Array
                  pkgs.join(" ")
                elsif pkgs.is_a? String
                  pkgs
                end
  end

  def no_packages_received?
    [@ubuntu, @fedora, @macos].all?(&:empty?)
  end
end
