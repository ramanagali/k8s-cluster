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
DNS_SERVERS=settings["network"]["dns_servers"].join(" ")
K8S_VERSION=settings['k8s_version']

# cr_settings = config_file['configs'][config_file['configs']['use_runtime']]
RUNTIME=settings['use_runtime']

# puts "{\n VM_BOX=#{VM_BOX},\n NUM_WORKER_NODES=#{NUM_WORKER_NODES},\n IP_NW=#{IP_NW},\n IP_START=#{IP_START},\n CONTROL_IP=#{CONTROL_IP},\n POD_CIDR=#{POD_CIDR},\n FORWARD_PORT=#{FORWARD_PORT}, \n RUNTIME=#{RUNTIME}\n}"
puts "--- Loaded Config.yaml Variables ---"

Vagrant.configure("2") do |config|

    # add host file entry
    config.vm.provision "shell", inline: <<-SHELL
        echo "$IP_NW$((IP_START))  master-node  master" >> /etc/hosts
        for i in `seq 1 ${NUM_WORKER_NODES}`; do
          echo "$IP_NW$((IP_START+1))  worker-node01  node01" >> /etc/hosts
        done
        # echo "nameserver #{settings['network']['dns_servers'][1]}" >> /etc/resolv.conf
        # echo "nameserver #{settings['network']['dns_servers'][1]}" >> /etc/resolv.conf
    SHELL

    config.vm.box=VM_BOX
    config.vm.box_check_update = true

    # master node ss
    config.vm.define "master" do |master|
      master.vm.hostname = "master"
      master.vm.network "private_network", ip: IP_NW + "#{IP_START}"
      master.vm.provider "virtualbox" do |vb|
          #vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
          vb.memory = settings["nodes"]["master"]["memory"]
          vb.cpus = settings["nodes"]["master"]["cpu"]
          vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
      end
      
      master.vm.provision "shell", env: {
        "K8S_VERSION" => K8S_VERSION,
        "RUNTIME" => RUNTIME,
        "DNS_SERVERS" => DNS_SERVERS
      },path: "scripts/common.sh"

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
          vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
        end
        node.vm.provision "shell", env: {
          "K8S_VERSION" => K8S_VERSION,
          "RUNTIME" => RUNTIME,
          "DNS_SERVERS" => DNS_SERVERS
        },path: "scripts/common.sh"

        node.vm.provision "shell", path: "scripts/node.sh"
      end
    end
  end