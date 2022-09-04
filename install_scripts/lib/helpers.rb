# frozen_string_literal: true

require 'etc'

module Helpers

  module OS

    # @return [String] OS
    #
    # @example "Linux"
    def sys
      Etc.uname[:sysname]
    end

    # @return [String] CPU architecture
    #
    # @example "x86_64"
    def arch
      Etc.uname[:machine]
    end

    # @return [String] Arch + OS
    #
    # @example "x86_64-linux"
    def platform
      RUBY_PLATFORM
    end

    def linux?
      sys == "Linux" || platform.match?(/linux/i)
    end

    def linux_distro_family
      linux_os_release_file[:ID_LIKE] || linux_os_release_file[:ID]
    end

    def linux_distro
      linux_os_release_file[:ID]
    end

    def linux_os_release_file
      warn 'distro not supported' unless File.exist?('/etc/os-release')

      output = {}

      File.read('/etc/os-release').each_line do |line|
        parsed_line = line.chomp.tr('"', '').split('=')
        next if parsed_line.empty?
        output[parsed_line[0].to_sym] = parsed_line[1]
      end

      output
    end

    def mac_os?
      sys == "Darwin" || platform.match?(/darwin/i)
    end

    def ubuntu?
      return false unless linux?

      [linux_distro_family, linux_distro, Etc.uname.fetch(:version, "")].any? do |distro|
        distro.match?(/ubuntu/i)
      end
    end

    def fedora?
      return false unless linux?

      [linux_distro_family, linux_distro, Etc.uname.fetch(:version, "")].any? do |distro|
        distro.match?(/fedora/i)
      end
    end
  end
end
