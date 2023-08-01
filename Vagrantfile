require 'yaml'

# Load settings from Config.yaml
current_dir = File.dirname(File.expand_path(__FILE__))
config_file = YAML.load_file("#{current_dir}/Config.yaml")
settings = config_file['configs']

# variables
VM_BOX=settings['box_name']
NUM_WORKER_NODES=settings['num_of_worker_nodes']
IP_NW=settings['network']['ip_address']
IP_START=settings['network']['ip_start']
CONTROL_IP=IP_NW + "#{IP_START}"
POD_CIDR=settings["network"]["pod_cidr"]
FORWARD_PORT=settings['network']['forward_port']
DNS=settings["network"]["dns_servers"].join(" ")

cr_settings = config_file['configs'][config_file['configs']['use_runtime']]
RUNTIME=settings['use_runtime']
RUNTIME_VERSION=cr_settings['runtime_version']

puts "{\n VM_BOX=#{VM_BOX},\n NUM_WORKER_NODES=#{NUM_WORKER_NODES},\n IP_NW=#{IP_NW},\n IP_START=#{IP_START},\n CONTROL_IP=#{CONTROL_IP},\n POD_CIDR=#{POD_CIDR},\n FORWARD_PORT=#{FORWARD_PORT}, \n RUNTIME=#{RUNTIME}, \n RUNTIME_VERSION=#{RUNTIME_VERSION}\n}"
puts "--- Loaded Config.yaml Variables ---"

Vagrant.configure("2") do |config|

    # add host file entry
    config.vm.provision "shell", inline: <<-SHELL
        echo "$IP_NW$((IP_START))  master-node  master" >> /etc/hosts
        for i in `seq 1 ${NUM_WORKER_NODES}`; do
          echo "$IP_NW$((IP_START+1))  worker-node01  node01" >> /etc/hosts
        done
        echo "nameserver #{settings['network']['dns_servers'][1]}" >> /etc/resolv.conf
        echo "nameserver #{settings['network']['dns_servers'][1]}" >> /etc/resolv.conf
    SHELL

    config.vm.box=VM_BOX
    config.vm.box_check_update = true
    # config.vm.synced_folder "configs", "/home/vagrant/configs"

    # master node ss
    config.vm.define "master" do |master|
      master.vm.hostname = "master"
      master.vm.network "private_network", ip: IP_NW + "#{IP_START}"
      master.vm.provider "virtualbox" do |vb|
          #vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
          vb.memory = settings["nodes"]["master"]["memory"]
          vb.cpus = settings["nodes"]["master"]["cpu"]
      end
      master.vm.provision "shell", env: {"RUNTIME" => RUNTIME, "RUNTIME_VERSION" => RUNTIME_VERSION},path: "scripts/common.sh"
      master.vm.provision "shell", env: {
        "MASTER_IP" => CONTROL_IP,
        "POD_CIDR" => POD_CIDR
      },path: "scripts/master.sh"
      master.vm.network :forwarded_port, guest: 6443, host: 6443, auto_correct: true
    end

    # worker node 
    (1..NUM_WORKER_NODES).each do |i|
      config.vm.define "node0#{i}" do |node|
        node.vm.hostname = "node0#{i}"
        node.vm.network "private_network", ip: IP_NW + "#{IP_START + i}"
        node.vm.provider "virtualbox" do |vb|
            #vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
            vb.memory = settings["nodes"]["worker"]["memory"]
          vb.cpus = settings["nodes"]["worker"]["cpu"]
        end
        node.vm.provision "shell", env: {"RUNTIME" => RUNTIME, "RUNTIME_VERSION" => RUNTIME_VERSION},path: "scripts/common.sh"
        node.vm.provision "shell", path: "scripts/node.sh"
      end
    end
  end