#!/bin/bash

pushd ~/se-support-reproducer-templates/terraform/
./setup.sh -y -c "../conf.env" -p lxd
popd

sudo iptables -t nat -I PREROUTING -i eno1np0 -p TCP -d 10.241.3.35 --dport 5240 -j DNAT --to-destination 10.250.120.2:5240

lxc exec maas --project se-repros -- bash << EOF
#!/bin/bash
maas login admin http://localhost:5240/MAAS/api/2.0/ `maas apikey --username admin`
maas admin sshkeys import lp:shunde-zhang
maas admin spaces create name=pxe-space
maas admin spaces create name=access-space
maas admin vlan update fabric-0 0 space=pxe-space
maas admin vlan update fabric-4 0 space=access-space
EOF

pushd ~
./setup_juju.sh
popd

lxc exec maas --project se-repros -- bash << EOF
#!/bin/bash
maas login admin http://localhost:5240/MAAS/api/2.0/ `maas apikey --username admin`
maas admin vm-host compose 1 hostname=cos1 cores=4 memory=8192 storage=sda:30,sdb:80
maas admin vm-host compose 1 hostname=cos2 cores=4 memory=8192 storage=sda:30,sdb:80
maas admin vm-host compose 1 hostname=cos3 cores=4 memory=8192 storage=sda:30,sdb:80
maas admin tags create name=k8s
maas admin machines read | jq '.[] | select(.hostname | contains("cos")) | .system_id ' | xargs -i maas admin tag update-nodes k8s add={}
EOF

lxc config device add cos1 eth1 nic network=se-repros-net name=eth1 --project maas-repros
lxc config device add cos2 eth1 nic network=se-repros-net name=eth1 --project maas-repros
lxc config device add cos3 eth1 nic network=se-repros-net name=eth1 --project maas-repros

lxc exec maas --project se-repros -- bash << EOF
maas login admin http://localhost:5240/MAAS/api/2.0/ `maas apikey --username admin`
maas admin machines read | jq '.[] | select(.hostname | contains("cos")) | .system_id ' | xargs -i maas admin machine commission {}
EOF
