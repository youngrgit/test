# 控制节点ip
CONTROLLER_IP=192.168.8.111
# 控制节点密码
CONTROLLER_PASS=000000
# 计算节点ip
COMPUTE_IP=192.168.8.112
# 计算节点密码
COMPUTE_PASS=000000
# 网络地址
NETWORK_IP=192.168.8.0/24
# 本机ip
LOCALHOST=192.168.8.111
# ------->若要使用本地镜像的话需要自己手动进行挂载,并且要设置永久挂载，否则后续可能会出问题<------
# centos包位置,要确保该源有足够的包
CENTOS_URL=http://10.255.9.214/centos7.9/
# openstack-train包位置，要确保该源有足够的包
IAAS_URL=http://10.255.9.214/openstack/

hostnamectl set-hostname controller

# 为系统的yum 源做备份
mkdir /etc/yum.repos.d/yum-bak
mv /etc/yum.repos.d/*repo /etc/yum.repos.d/yum-bak/

# 配置centos yum源
cat > /etc/yum.repos.d/centos7-9.repo << young
[centos7.9]
name=centos
baseurl=$CENTOS_URL
enabled=1
gpgcheck=0
young
# 配置openstack-train版 yum源
cat > /etc/yum.repos.d/openstack.repo << young
[openstack]
name=openstack
baseurl=$IAAS_URL
enabled=1
gpgcheck=0
young

yum clean all
yum makecache

cat >> /etc/hosts << young
$CONTROLLER_IP controller
$COMPUTE_IP compute
young

#firewalld
systemctl stop firewalld
systemctl disable firewalld  >> /dev/null 2>&1

#NetworkManager
systemctl stop NetworkManager >> /dev/null 2>&1
systemctl disable NetworkManager >> /dev/null 2>&1
yum remove -y NetworkManager firewalld
systemctl restart network
 
#iptables
iptables -F
iptables -X
iptables -Z
/usr/sbin/iptables-save
systemctl stop iptables
systemctl disable iptables

yum install python-openstackclient openstack-selinux openstack-utils crudini expect -y

#ssh
if [[ ! -s ~/.ssh/id_rsa.pub ]];then
    ssh-keygen  -t rsa -N '' -f ~/.ssh/id_rsa -q -b 2048
fi
name=`hostname`
if [[ $name == controller ]];then
expect -c "set timeout -1;
               spawn ssh-copy-id  -i /root/.ssh/id_rsa $COMPUTE_IP;
               expect {
                   *password:* {send -- $COMPUTE_PASS\r;
                        expect {
                            *denied* {exit 2;}
                            eof}
                    }
                   *(yes/no)* {send -- yes\r;exp_continue;}
                   eof         {exit 1;}
               }
               "
else
expect -c "set timeout -1;
               spawn ssh-copy-id  -i /root/.ssh/id_rsa $CONTROLLER_IP;
               expect {
                   *password:* {send -- $CONTROLLER_PASS\r;
                        expect {
                            *denied* {exit 2;}
                            eof}
                    }
                   *(yes/no)* {send -- yes\r;exp_continue;}
                   eof         {exit 1;}
               }
               "
fi


#chrony
yum install -y chrony
if [[ $name == controller ]];then
        sed -i '3,6s/^/#/g' /etc/chrony.conf
        sed -i '7s/^/server controller iburst/g' /etc/chrony.conf
        echo "allow all" >> /etc/chrony.conf
        echo "local stratum 10" >> /etc/chrony.conf
else
        sed -i '3,6s/^/#/g' /etc/chrony.conf
        sed -i '7s/^/server controller iburst/g' /etc/chrony.conf
fi

systemctl restart chronyd
systemctl enable chronyd

yum -y install iaas-xiandian

cat > /etc/xiandian/openrc.sh << young
HOST_IP=$CONTROLLER_IP
HOST_PASS=$CONTROLLER_PASS
HOST_NAME=controller
HOST_IP_NODE=$COMPUTE_IP
HOST_PASS_NODE=000000
HOST_NAME_NODE=compute
network_segment_IP=$NETWORK_IP
RABBIT_USER=openstack
RABBIT_PASS=000000
DB_PASS=000000
DOMAIN_NAME=demo
ADMIN_PASS=000000
DEMO_PASS=000000
KEYSTONE_DBPASS=000000
GLANCE_DBPASS=000000
GLANCE_PASS=000000
NOVA_DBPASS=000000
NOVA_PASS=000000
NEUTRON_DBPASS=000000
NEUTRON_PASS=000000
METADATA_SECRET=000000
INTERFACE_IP=$LOCALHOST
INTERFACE_NAME=ens34
Physical_NAME=provider
minvlan=101
maxvlan=200
CINDER_DBPASS=000000
CINDER_PASS=000000
BLOCK_DISK=vdb1
SWIFT_PASS=000000
OBJECT_DISK=vdb2
STORAGE_LOCAL_NET_IP=$COMPUTE_IP
HEAT_DBPASS=000000
HEAT_PASS=000000
ZUN_DBPASS=000000
ZUN_PASS=000000
KURYR_DBPASS=000000
KURYR_PASS=000000
CEILOMETER_DBPASS=000000
CEILOMETER_PASS=000000
AODH_DBPASS=000000
AODH_PASS=000000
BARBICAN_DBPASS=000000
BARBICAN_PASS=000000
young

iaas-install-mysql.sh
iaas-install-keystone.sh
iaas-install-glance.sh
iaas-install-nova-controller.sh
iaas-install-neutron-controller.sh
iaas-install-dashboard.sh

#--------------------------------------------
# author：young
# Version: 1.0
# Date: 2022-7-7
#--------------------------------------------
