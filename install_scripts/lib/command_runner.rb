# frozen_string_literal: true

class CommandRunner
  include Helpers::OS

  def self.run(ubuntu: "", fedora: "", mac_os: "")
    new(ubuntu:, fedora:, mac_os:).run
  end

  def initialize(ubuntu:, fedora:, mac_os:)
    @ubuntu = ubuntu
    @fedora = fedora
    @mac_os = mac_os
  end

  def run
    raise ArgumentError.new('No command was received') if no_command_received?

    cmd = if mac_os? && !@mac_os.empty?
            @mac_os
          elsif ubuntu? && !@ubuntu.empty?
            @ubuntu
          elsif fedora? && !@fedora.empty
            @fedora
          else
            ''
          end

    system(cmd)
  end

  private

  def no_command_received?
    [ @ubuntu, @fedora, @macos ].all?(&:empty?)
  end
end
