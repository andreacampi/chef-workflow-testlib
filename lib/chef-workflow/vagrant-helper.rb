require 'vagrant/dsl'
require 'chef-workflow/support/debug'
require 'chef-workflow/support/vagrant'
require 'chef-workflow/support/ip'
require 'chef-workflow/knife-helper'
require 'thread'

module VagrantHelper
  include DebugSupport
  include Vagrant::DSL
  include KnifeHelper

  def vagrant_build_role(role_name, number_of_machines=1)
    IPSupport.singleton.seed_vagrant_ips

    if_debug do
      $stderr.puts "Bringing up #{number_of_machines} machines for prison #{role_name}"
    end

    prison = vagrant_prison(:auto_destroy => false, :ui_class => Vagrant::UI::Silent) do
      configure do |config|
        config.vm.box_url = VagrantSupport.singleton.box_url
        config.vm.box = VagrantSupport.singleton.box
        number_of_machines.times do |count|
          ip = IPSupport.singleton.unused_ip
          IPSupport.singleton.assign_role_ip(role_name, ip)
          config.vm.define "#{role_name}_#{count}".to_sym do |this_config|
            this_config.vm.network :hostonly, ip
          end
        end
      end

      vagrant_up
    end

    prison.name = role_name

    VagrantSupport.singleton.write_prison(role_name, prison)
    return prison, IPSupport.singleton.get_role_ips(role_name)
  end

  def vagrant_bootstrap(role_name, number_of_machines=1)
    prison, ips = vagrant_build_role(role_name, number_of_machines)
    node_names = knife_bootstrap_role(role_name)
    return prison, ips, node_names
  end

  def vagrant_cleanup(prisons, node_names)
    prisons = [prisons] unless prisons.kind_of?(Array)
    prisons.each do |prison|
      if_debug do
        $stderr.puts "Cleaning up prison for role #{prison.name}"
      end
      # FIXME ui_class will still be silent here, make this debuggable
      prison.cleanup
      VagrantSupport.singleton.remove_prison(prison.name)
    end
    knife_destroy(node_names)
  end
end
