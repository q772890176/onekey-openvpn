# !/bin/bash
#***************************************************************************************************************************************************#
# CenTos6 OpenVpn VPN Install Script                                                                           #
# Author: wangmingxuan                                                                                             #  
# Web: http://wangmingxuan.cn http://www.myzhenai.com.cn http://www.myzhenai.com http://www.haikou-china.com http://jiayu.mybabya.com #
#***************************************************************************************************************************************************#
yum install redhat-lsb curl -y
el=`rpm -qa |grep epel` && yum -q remove $el -y
rp=`rpm -qa |grep rpmforge` && yum -q remove $rp -y
version=`lsb_release -a|grep -e Release|awk -F ":" '{ print $2 }'|awk -F "." '{ print $1 }'`



# 关闭selinux
setenforce 0
sed -i '/^SELINUX=/c\SELINUX=disabled' /etc/selinux/config
 
# 安装openssl和lzo，lzo用于压缩通讯数据加快传输速度
yum -y install openssl openssl-devel
yum -y install lzo
 
# 安装epel源
rpm -ivh http://mirrors.sohu.com/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
sed -i 's/^mirrorlist=https/mirrorlist=http/' /etc/yum.repos.d/epel.repo

wget http://wangmingxuan.cn/download/rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm
rpm -iv rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm
rm -rf rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm


yum remove openvpn -y
rm -rf /etc/openvpn/*
rm -rf /home/vpn
rm -rf /home/vpn.tar.gz
yum update -y
yum install gcc gcc-c++ lrzsz lzo openssl openssl-devel iptables pkcs11-helper pkcs11-helper-devel openssh-clients openvpn easy-rsa -y
easy=`find / -name easy-rsa` && cp -R $easy /etc/openvpn/
#if ! [ -d "$easy"];then
#yum install easy-rsa -y
#cp -R $easy /etc/openvpn/
#else
#cp -R $easy /etc/openvpn/
#fi
cd /etc/openvpn/easy-rsa/2.0/
chmod +rwx *
./vars
sed -i 's/export KEY_COUNTRY="US"/export KEY_COUNTRY="CN"/g' vars
sed -i 's/export KEY_PROVINCE="CA"/export KEY_PROVINCE="HN"/g' vars
sed -i 's/export KEY_CITY="SanFrancisco"/export KEY_CITY="HAIKOU"/g' vars
sed -i 's/export KEY_ORG="Fort-Funston"/export KEY_ORG="OpenVPN"/g' vars
sed -i 's/export KEY_EMAIL="me@myhost.mydomain"/export KEY_EMAIL="root@foxmail.com"/g' vars
sed -i 's/export KEY_EMAIL=mail@host.domain/export KEY_EMAIL=root@foxmail.com/g' vars
server=`find / -name sample-config-files` && cp $server/server.conf /etc/openvpn/

server_conf='
port 1194\n
proto udp\n
dev tun\n
ca ca.crt\n
cert server.crt\n
key server.key  # This file should be kept secret\n
dh dh2048.pem\n
server 10.8.0.0 255.255.255.0\n
ifconfig-pool-persist ipp.txt\n
push "route 0.0.0.0 0.0.0.0"\n
push "redirect-gateway def1 bypass-dhcp"\n
push "dhcp-option DNS 114.114.114.114"\n
push "dhcp-option DNS 8.8.8.8"\n
client-to-client\n
keepalive 10 120\n
comp-lzo\n
persist-key\n
persist-tun\n
status openvpn-status.log\n
verb 3
log openvpn
'
echo -e "$server_conf" > /etc/openvpn/server.conf


sysctl -w net.ipv4.ip_forward=1
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
. ./vars
./clean-all
#echo -e "\n\n\n\n\n\n\n\n" | ./build-ca
#echo -e "\n\n\n\n\n\n\n\n\n\n" | ./build-key-server server && echo -e "\n\n\n\n\n\n\n\n\n\n" | ./build-key client-name
./build-ca
./build-key-server server
./build-key client-name
./build-dh
openssl rsa -in keys/client-name.key -out keys/client-name.pem
chmod +x keys/*
mkdir /home/vpn
size=`grep 'export KEY_SIZE=1024' $easy/2.0/vars`
if [[ $size == "export KEY_SIZE=1024" ]];then
cp keys/{ca.crt,ca.key,client-name.crt,client-name.csr,client-name.key,server.crt,server.key,dh1024.pem,client-name.pem} /etc/openvpn/
cp keys/{ca.crt,ca.key,client-name.crt,client-name.csr,client-name.key,server.crt,server.key,dh1024.pem,client-name.pem} /home/vpn/
else
cp keys/{ca.crt,ca.key,client-name.crt,client-name.csr,client-name.key,server.crt,server.key,dh2048.pem,client-name.pem} /etc/openvpn/
cp keys/{ca.crt,ca.key,client-name.crt,client-name.csr,client-name.key,server.crt,server.key,dh2048.pem,client-name.pem} /home/vpn/
fi
ip=`ifconfig | awk -F'[ ]+|:' '/inet addr/{if($4!~/^192.168|^172.16|^10|^127|^0/) print $4}'`

client_conf='
client\n
dev tun\n
proto udp\n
remote $ip 1194\n
resolv-retry infinite\n
nobind\n
persist-key\n
persist-tun\n
ca ca.crt\n
cert client-name.crt\n
key client-name.key\n
ns-cert-type server\n
comp-lzo\n
verb 3\n
route-method exe\n
route-delay 2\n
'
echo  -e "$client_conf" > /home/vpn/wmx.ovpn

cd /home/
tar -zcvf vpn.tar.gz vpn/*
cd /
#ip=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
#ip=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|awk -F ":" '{ print $2 }'`

iptables -F
service iptables save
service iptables restart
iptables -A INPUT -p tcp --dport 1194 -j ACCEPT
iptables -A INPUT -p udp --dport 1194 -j ACCEPT
iptables -A INPUT -p tcp --dport 1723 -j ACCEPT
iptables -A INPUT -p tcp --dport 47 -j ACCEPT
iptables -A INPUT -p tcp --dport 2009 -j ACCEPT
iptables -A INPUT -p udp --dport 2009 -j ACCEPT
iptables -A INPUT -p gre -j ACCEPT
iptables -t nat -A POSTROUTING -j MASQUERADE 
iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -j SNAT --to-source $ip
iptables -t nat -A POSTROUTING -s 10.8.0.20/24 -j SNAT --to-source $ip
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to-source $ip
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -j SNAT --to-source $ip
service iptables save
service iptables restart
#con=`grep '/usr/sbin/openvpn –config /etc/openvpn/server.conf &'` /etc/rc.local
#if [[ $con != "/usr/sbin/openvpn –config /etc/openvpn/server.conf &" ]];then
echo '/usr/sbin/openvpn –config /etc/openvpn/server.conf &' >> /etc/rc.local
#fi
#openvpn --config /etc/openvpn/server.conf &
chkconfig openvpn on
chkconfig iptables on
service openvpn start
el=`rpm -qa |grep epel` && yum -q remove $el -y
rp=`rpm -qa |grep rpmforge` && yum -q remove $rp -y
rm -rf *.rpm
yum clean all

echo '****  /home/vpn.tar.gz      ****';