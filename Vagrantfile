VM_BOX="bento/ubuntu-22.04"
NUM_WORKER_NODES=1
IP_NW="192.168.56."
IP_START=10

Vagrant.configure("2") do |config|

    # add host file entry
    config.vm.provision "shell", inline: <<-SHELL
        echo "$IP_NW$((IP_START))  master-node  master" >> /etc/hosts
        echo "$IP_NW$((IP_START+1))  worker-node01  node01" >> /etc/hosts
        echo "nameserver 8.8.8.8" >> /etc/resolv.conf
        echo "nameserver 8.8.4.4" >> /etc/resolv.conf
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
          vb.memory = 4096
          vb.cpus = 2
      end
      master.vm.provision "shell", path: "scripts/common.sh"
      master.vm.provision "shell", path: "scripts/master.sh"
      master.vm.network :forwarded_port, guest: 6443, host: 6443, auto_correct: true
    end

    # worker node 
    (1..NUM_WORKER_NODES).each do |i|
      config.vm.define "worker#{i}" do |node|
        node.vm.hostname = "worker#{i}"
        node.vm.network "private_network", ip: IP_NW + "#{IP_START + i}"
        node.vm.provider "virtualbox" do |vb|
            #vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
            vb.memory = 2048
            vb.cpus = 1
        end
        node.vm.provision "shell", path: "scripts/common.sh"
        node.vm.provision "shell", path: "scripts/node.sh"
      end
    end

  end