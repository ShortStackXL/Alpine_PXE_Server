#This script is a quick setup script for common Alpine server services.
#Below is a template I use in my /etc/motd config as a quick dashboard of configured services on log in.
#Feel free to use it however you see fit. It also reflects the general setup of the provided services.
#
#================================================================
#
#General Server Information (Packages/Services/Configurations):
#Ex. Service (Package) /path/to/conf/ || /other/service/resources
#
#        Active Services:
#
#DHCP (dnsmasq) /etc/dnsmasq.conf | Range = 10.0.0.* - 10.0.0.* |
#TFTP (dnsmasq) /etc/dnsmasq.conf /srv/tftp
#PXE (dnsmasq,pxelinux/syslinux) /etc/dnsmasq.conf /srv/tftp/default
#SSH / SFTP (openssh) /etc/ssh/ssh_config
#HTTP (nginx) /etc/nginx/nginx.conf /srv/http /srv/http/sslcerts
#DNS (dnsmasq) /etc/dnsmasq.conf /etc/hosts /etc/resolv.conf
#NFS (nfs-utils) /etc/exports
#FTP (vsftpd) /etc/vsftpd/vsftpd.conf
#Containers (docker)
#802.11 Hotspot (hostapd) /etc/hostapd/hostapd.conf
#
#
#        Inactive Services:
#
#
#================================================================

#!bin/sh

cat <<EOF

Hello, "$USER"

Please pick the services you would like to install:

1) DHCP | DNS | TFTP | PXE / BOOTP  -->  DNSMasq & SYS/PXE Linux  <--
2) SSH / SFTP                       -->  OpenSSH   <--
3) FTP                              -->  VSFTPD    <--
4) HTTPS / HTTP                     -->  Nginx     <--
5) NFS                              -->  NFS-utils <--
6) 802.11 Hotspot                   -->  Hostapd   <--
7) Containers                       -->  Docker    <--

e) Exit

EOF

read -p "Enter number of desired service(s): " -n 2 input;

case "$input" in

1)

#Downloads needed packages

doas apk add -v dnsmasq syslinux;

if [ $? != 0 ]
then

cat <<'EOF';
***************************************************
*Error! Packages could not be installed. Aborting.*
***************************************************
EOF

exit 2;

fi



#Makes TFTP directory structure in /srv
doas mkdir -p /srv/tftp /srv/tftp/BIOS/pxelinux.cfg /srv/tftp/UEFI/pxelinux.cfg /srv/tftp/Images /srv/tftp/apkovls;
doas touch /srv/tftp/default;
doas chmod -Rv 755 /srv/tftp;



#Makes symlinks and distributes for single point of administration
ln -sv /srv/tftp/Images /srv/tftp/BIOS/Images;
ln -sv /srv/tftp/apkovls /srv/tftp/BIOS/apkovls;
ln -sv /srv/tftp/default /srv/tftp/BIOS/pxelinux.cfg/default;

cp -f /srv/tftp/BIOS/Images /srv/tftp/BIOS/apkovls -t /srv/tftp/UEFI;
cp -f /srv/tftp/BIOS/pxelinux.cfg/default -t /srv/tftp/UEFI/pxelinux.cfg/default;



#Downloads Alpine Netboot x86 and uncompresses files into organized image directory
mkdir -p /srv/tftp/Images/Alpine-Netboot-x86;
wget https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86/alpine-netboot-3.24.2-x86.tar.gz -O /srv/tftp/Images/Alpine-Netboot-x86;
tar -xfv /srv/tftp/Images/Alpine-Netboot-x86/alpine-netboot-3.24.2-x86.tar.gz -C /srv/tftp/Images/Alpine-Netboot-x86;
mv -f /srv/tftp/Images/Alpine-Netboot-x86/boot/* -t /srv/tftp/Images/Alpine-Netboot-x86;
rm -Rf /srv/tftp/Images/Alpine-Netboot-x86/alpine-netboot-3.24.2-x86.tar.gz /srv/tftp/Images/Alpine-Netboot-x86/boot;

#Downloads Alpine Netboot x86_64 and uncompresses files into organized image directory
mkdir -p /srv/tftp/Images/Alpine-Netboot-x86_64;
wget https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-netboot-3.24.2-x86_64.tar.gz -O /srv/tftp/Images/Alpine-Netboot-x86_64;
tar -xfv /srv/tftp/Images/Alpine-Netboot-x86_64/alpine-netboot-3.24.2-x86_64.tar.gz -C /srv/tftp/Images/Alpine-Netboot-x86_64;
mv -f /srv/tftp/Images/Alpine-Netboot-x86_64/boot/* -t /srv/tftp/Images/Alpine-Netboot-x86_64;
rm -Rf /srv/tftp/Images/Alpine-Netboot-x86_64/alpine-netboot-3.24.2-x86_64.tar.gz /srv/tftp/Images/Alpine-Netboot-x86_64/boot;

doas chmod -Rv 755 /srv/tftp;



#Copies needed binaries and bootloaders into the appropriate directories
cp -f /usr/share/syslinux/pxelinux.0 /usr/share/syslinux/ldlinux.c32 /usr/share/syslinux/menu.c32 /usr/share/syslinux/libutil.c32 -t /srv/tftp/BIOS;
cp -f /usr/share/syslinux/efi64/syslinux.efi /usr/share/syslinux/efi64/ldlinux.e64 /usr/share/syslinux/efi64/menu.c32 /usr/share/syslinux/efi64/libutil.c32 -t /srv/tftp/UEFI;



#Edits /etc/dnsmasq.conf, starts dnsmasq service, and adds the service to runlevel default for persistence on startup.

#Copies original .conf file to insert template on top of.
doas cp -f /etc/dnsmasq.conf -t /tmp

cat <<'EOF' > /tmp/dnsmasq_custom.conf
#Currently active settings:

#=====================================

#DNS settings:

#server=/
#local=/internal/
#dnssec-check-unsigned

#strict-order
#local-service
#except-interface=wlan0

#=====================================

#DHCP settings:

#local-service
#enable-ra

#dhcp-range=10.0.0.241,10.0.0.253,4h

#Default Gateway
#dhcp-option=3, 10.0.0.1

#DNS Server
#dhcp-option=6, 10.0.0.221,75.75.75.75,75.75.76.76
#dhcp-option=option:domain-search,internal

#=====================================

#TFTP settings:

enable-tftp
tftp-no-fail
tftp-no-blocksize
tftp-root=/srv/tftp

#=====================================

#PXE boot settings:

dhcp-boot=BIOS/pxelinux.0
#dhcp-boot=UEFI/syslinux.efi
#pxe-prompt="Choose:"

#=====================================

EOF

#Creates custom dnsmasq.conf file and cleans up temp files used to create it.
cat /tmp/dnsmasq_custom.conf /tmp/dnsmasq.conf > /tmp/new_custom_dnsmasq.conf;
doas mv -f /tmp/new_custom_dnsmasq.conf -t /etc/dnsmasq.conf;
rm -Rf /tmp/*;

doas service dnsmasq start;
doas rc-update add dnsmasq runlevel;



#Edits PXELinux config file at /srv/tftp/default

#Copies template information into the default conf file then saves and quits.

doas cat <<'EOF' > /srv/tftp/default;
PXE Linux Boot Options

DEFAULT menu.c32
PROMPT 0

MENU TITLE Boot Menu
MENU AUTOBOOT Launching local OS in # Seconds
TIMEOUT 10

LABEL Local Boot
    MENU LABEL Local Boot
    MENU DEFAULT
    LOCALBOOT 0

MENU SEPARATOR

LABEL Alpine Netboot x86
        MENU LABEL Linux Alpine Netboot (x86)
        KERNEL /Images/Alpine-Netboot-x86/vmlinuz-lts
        INITRD /Images/Alpine-Netboot-x86/initramfs-lts
        APPEND modloop=http://charlie.internal/Images/Alpine-Netboot-x86/modloop-lts ip=dhcp alpine_repo=http://charlie.internal/apks,https://dl-cdn.alpinelinux.org/alpine/v3.24/main,https://dl-cdn.alpinelinux.org/alpine/v3.24/community

MENU SEPARATOR

LABEL Alpine Netboot x86_64
        MENU LABEL Linux Alpine Netboot (x64)
        KERNEL /Images/Alpine-Netboot-x86_64/vmlinuz-lts
        INITRD /Images/Alpine-Netboot-x86_64/initramfs-lts
        APPEND modloop=http://charlie.internal/Images/Alpine-Netboot-x86_64/modloop-lts ip=dhcp alpine_repo=http://charlie.internal/apks,https://dl-cdn.alpinelinux.org/alpine/v3.24/main,https://dl-dn.alpinelinux.org/alpine/v3.24/community

MENU SEPARATOR

LABEL Linux Mint Debian Edition (x86)
        MENU LABEL Linux Mint Debian Edition (x86)
        KERNEL /Images/LMDE_6/live/vmlinuz
        INITRD /Images/LMDE_6/live/initrd.lz
        APPEND ip=dhcp root=/dev/nfs nfsroot=10.0.0.221:/srv/nfs

MENU SEPARATOR


#Useful Kernel Boot Parameters

#pkgs=[pkg,pkg,...] ex. nfs-utils,openssh,...
#apkovl=[URL of APK overlay] ex. http://delta.local/testgui.apkovl.tar.gz
#alpine_repo=[URL of Alpine repo]
#init=[path to init process]
#initrd=[path/to/initramfs] *THIS BOOT PARAMETER NEEDS TO BE IN THE APPEND LINE IF BOOTING USING UEFI. IF IT DOESN'T IT WILL NOT PROPERLY LOAD THE INITRAMFS!!!
#root=[root device] ex. /dev/nfs OR /dev/sda etc...
#nfsroot=[Server IP Addr]:[/full/nfs/path/foo/bar]
#console=[specify console to load upon boot] ex. tty0
#single [for single user mode]
#debug [maximum verbosity for debug info]
#quiet [suppress boot messages]
#modloop=http://delta.internal/Images/Alpine-Netboot-x86/modloop-lts [/modloop/file/path]
#modules=[loop,squashfs,...]
EOF



#This is just to ensure all files needed are read-enabled.
doas chmod -Rv 755 /srv/tftp;

;;

2)

doas apk add openssh;

if [ $? != 0 ]
then

cat <<'EOF';
***************************************************
*Error! Packages could not be installed. Aborting.*
***************************************************
EOF

exit 2;

fi

if [ -z "/srv/ftp" ]
then

#Make directory to host FTP files.
mkdir -p /srv/ftp;

fi

echo "Process completed successfully! SSH/SFTP services have been installed. Custom configuration template has been created.";

exit 0;

;;

3)

doas apk add vsftpd;

if [ $? != 0 ]
then

cat <<'EOF'
***************************************************
*Error! Packages could not be installed. Aborting.*
***************************************************
EOF

exit 2;

fi

if [ -z "/srv/ftp" ]
then

#Make directory to host FTP files.
mkdir -p /srv/ftp;

fi

cat <<'EOF' > /tmp/vsftpd_custom.conf;
#=================================================

#User Settings:

#anonymous_enable=YES
#no_anon_password=YES
#allow_writable_chroot=YES
#anon_root=/srv/ftp
#anon_mkdir_write_enable=YES
#anon_other_write_enable=YES
#anon_upload_enable=YES
local_enable=YES
chown_uploads=YES
chown_username=nobody
chmod_enable=YES
ls_recurse_enable=YES
nopriv_user=nobody

#=================================================

#Server Settings:

local_root=/srv/ftp
write_enable=YES
listen=YES
#seccomp_sandbox causes issue with requiring privileged sockets. Error 500 OOPS priv_sock_get_cmd. Change to NO.
seccomp_sandbox=NO
use_localtime=YES
#listen_ipv6=YES
#connect_from_port_20=YES
lock_upload_files=NO

#=================================================

#Log Settings:

xferlog_enable=YES

#=================================================

#Message Settings

dirmessage_enable=YES
ftpd_banner=Welcome to the FTP server!

#=================================================

EOF

#Creates custom vsftpd.conf file and cleans up temp files used to create it.
doas cp -f /etc/vsftpd/vsftpd.conf -t /tmp;
cat /tmp/vsftpd_custom.conf /tmp/vsftpd.conf > /tmp/new_custom_vsftpd.conf;
doas mv -f /tmp/new_custom_vsftpd.conf -t /etc/vsftpd/vsftpd.conf;
rm -Rf /tmp/*;

echo "";
echo "Custom hostapd.conf template has been generated and stored in /etc/vsftpd/vsftpd.conf.";
echo "";

#Starts service and adds to default level runtime
doas service vsftpd start;
doas rc-update add vsftpd runlevel;

echo "Process completed successfully! FTP services have been installed and added to system startup. Custom configuration template has been created.";

exit 0;

;;

4)

doas apk add nginx;

if [ $? != 0 ]
then

cat <<'EOF';
***************************************************
*Error! Packages could not be installed. Aborting.*
***************************************************
EOF

exit 2;

fi

if [ -z "/srv/http" ]
then

#Make directory to host HTTP web server files.
mkdir -p /srv/http;

fi

#Checks if user has a home directory and saves nginx.conf template there or in the /srv directory if not
if [ -z "/home/$USER" ]
then

doas cat <<'EOF' > /srv/nginx.conf;
# /etc/nginx/nginx.conf

user nginx;

# Set number of worker processes automatically based on number of CPU cores.
worker_processes auto;

# Enables the use of JIT for regular expressions to speed-up their processing.
pcre_jit on;

# Configures default error logger.
error_log /var/log/nginx/error.log warn;

# Includes files with directives to load dynamic modules.
include /etc/nginx/modules/*.conf;

# Include files with config snippets into the root context.
include /etc/nginx/conf.d/*.conf;

events {
        # The maximum number of simultaneous connections that can be opened by
        # a worker process.
        worker_connections 1024;
}

http {
        # Includes mapping of file name extensions to MIME types of responses
        # and defines the default type.
        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        # Name servers used to resolve names of upstream servers into addresses.
        # It's also needed when using tcpsocket and udpsocket in Lua modules.
        #resolver 1.1.1.1 1.0.0.1 [2606:4700:4700::1111] [2606:4700:4700::1001];
        #resolver 10.0.0.201 127.0.0.1 [2601:cd:c381:f260:215:5dff:fea0:5a07];

        # Don't tell nginx version to the clients. Default is 'on'.
        server_tokens off;

        # Specifies the maximum accepted body size of a client request, as
        # indicated by the request header Content-Length. If the stated content
        # length is greater than this size, then the client receives the HTTP
        # error code 413. Set to 0 to disable. Default is '1m'.
        client_max_body_size 1m;

        # Sendfile copies data between one FD and other from within the kernel,
        # which is more efficient than read() + write(). Default is off.
        sendfile on;

        # Causes nginx to attempt to send its HTTP response head in one packet,
        # instead of using partial frames. Default is 'off'.
        tcp_nopush on;


        # Enables the specified protocols. Default is TLSv1 TLSv1.1 TLSv1.2.
        # TIP: If you're not obligated to support ancient clients, remove TLSv1.1.
        ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;

        # Path of the file with Diffie-Hellman parameters for EDH ciphers.
        # TIP: Generate with: `openssl dhparam -out /etc/ssl/nginx/dh2048.pem 2048`
        ssl_dhparam /root/ssl/dh2048.pem;

        # Specifies that our cipher suits should be preferred over client ciphers.
        # Default is 'off'.
        ssl_prefer_server_ciphers on;

        # Enables a shared SSL cache with size that can hold around 8000 sessions.
        # Default is 'none'.
        ssl_session_cache shared:SSL:2m;

        # Specifies a time during which a client may reuse the session parameters.
        # Default is '5m'.
        ssl_session_timeout 5m;

        # Disable TLS session tickets (they are insecure). Default is 'on'.
        ssl_session_tickets off;

        # Enable gzipping of responses.
        #gzip on;

        # Set the Vary HTTP header as defined in the RFC 2616. Default is 'off'.
        gzip_vary on;


        # Helper variable for proxying websockets.
        map $http_upgrade $connection_upgrade{
                default upgrade;
                '' close;
                }

                server {
                        server_name charlie.internal charlie 10.0.0.221 10.0.0.222;
                        listen 80;
                        listen 443 ssl;
                        listen [::]:80;
                        listen [::]:443;

                        ssl_certificate /root/ssl/charlie.internal.crt;
                        ssl_certificate_key /root/ssl/charlie.internal.pem;

                location / {
                        root /srv/http;
                        autoindex on;
                        autoindex_exact_size off;
                        index index.html index.htm;
                        client_max_body_size 32m;
                        }

                        error_page 500 502 503 504 /50x.html;
                        location = /50x.html {
                                root /var/lib/nginx/html;
                        }


        }


        # Specifies the main log format.
        log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for"';

        # Sets the path, format, and configuration for a buffered log write.
        access_log /var/log/nginx/access.log main;


        # Includes virtual hosts configs.
        include /etc/nginx/http.d/*.conf;
}

EOF

doas chown -Rv nginx:nginx /srv/http && doas chmod -Rv 755 /svr/http;

echo "";
echo "Custom nginx.conf template has been generated and stored in /srv/nginx.conf.";
echo "";


else


cat <<'EOF' > /home/"$USER"/nginx.conf;
# /etc/nginx/nginx.conf

user nginx;

# Set number of worker processes automatically based on number of CPU cores.
worker_processes auto;

# Enables the use of JIT for regular expressions to speed-up their processing.
pcre_jit on;

# Configures default error logger.
error_log /var/log/nginx/error.log warn;

# Includes files with directives to load dynamic modules.
include /etc/nginx/modules/*.conf;

# Include files with config snippets into the root context.
include /etc/nginx/conf.d/*.conf;

events {
        # The maximum number of simultaneous connections that can be opened by
        # a worker process.
        worker_connections 1024;
}

http {
        # Includes mapping of file name extensions to MIME types of responses
        # and defines the default type.
        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        # Name servers used to resolve names of upstream servers into addresses.
        # It's also needed when using tcpsocket and udpsocket in Lua modules.
        #resolver 1.1.1.1 1.0.0.1 [2606:4700:4700::1111] [2606:4700:4700::1001];
        #resolver 10.0.0.201 127.0.0.1 [2601:cd:c381:f260:215:5dff:fea0:5a07];

        # Don't tell nginx version to the clients. Default is 'on'.
        server_tokens off;

        # Specifies the maximum accepted body size of a client request, as
        # indicated by the request header Content-Length. If the stated content
        # length is greater than this size, then the client receives the HTTP
        # error code 413. Set to 0 to disable. Default is '1m'.
        client_max_body_size 1m;

        # Sendfile copies data between one FD and other from within the kernel,
        # which is more efficient than read() + write(). Default is off.
        sendfile on;

        # Causes nginx to attempt to send its HTTP response head in one packet,
        # instead of using partial frames. Default is 'off'.
        tcp_nopush on;


        # Enables the specified protocols. Default is TLSv1 TLSv1.1 TLSv1.2.
        # TIP: If you're not obligated to support ancient clients, remove TLSv1.1.
        ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;

        # Path of the file with Diffie-Hellman parameters for EDH ciphers.
        # TIP: Generate with: `openssl dhparam -out /etc/ssl/nginx/dh2048.pem 2048`
        ssl_dhparam /root/ssl/dh2048.pem;

        # Specifies that our cipher suits should be preferred over client ciphers.
        # Default is 'off'.
        ssl_prefer_server_ciphers on;

        # Enables a shared SSL cache with size that can hold around 8000 sessions.
        # Default is 'none'.
        ssl_session_cache shared:SSL:2m;

        # Specifies a time during which a client may reuse the session parameters.
        # Default is '5m'.
        ssl_session_timeout 5m;

        # Disable TLS session tickets (they are insecure). Default is 'on'.
        ssl_session_tickets off;

        # Enable gzipping of responses.
        #gzip on;

        # Set the Vary HTTP header as defined in the RFC 2616. Default is 'off'.
        gzip_vary on;


        # Helper variable for proxying websockets.
        map $http_upgrade $connection_upgrade{
                default upgrade;
                '' close;
                }

                server {
                        server_name charlie.internal charlie 10.0.0.221 10.0.0.222;
                        listen 80;
                        listen 443 ssl;
                        listen [::]:80;
                        listen [::]:443;

                        ssl_certificate /root/ssl/charlie.internal.crt;
                        ssl_certificate_key /root/ssl/charlie.internal.pem;

                location / {
                        root /srv/http;
                        autoindex on;
                        autoindex_exact_size off;
                        index index.html index.htm;
                        client_max_body_size 32m;
                        }

                        error_page 500 502 503 504 /50x.html;
                        location = /50x.html {
                                root /var/lib/nginx/html;
                        }


        }


        # Specifies the main log format.
        log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for"';

        # Sets the path, format, and configuration for a buffered log write.
        access_log /var/log/nginx/access.log main;


        # Includes virtual hosts configs.
        include /etc/nginx/http.d/*.conf;
}

EOF

doas chown -Rv nginx:nginx /srv/http && doas chmod -Rv 755 /svr/http;

echo "";
echo "Custom nginx.conf template has been generated and stored in /home/$USER/nginx.conf.";
echo "";

fi

#Starts service and adds to default level runtime
doas service nginx start;
doas rc-update add nginx runlevel;

echo "Process completed successfully! HTTP services have been installed and added to system startup. Custom configuration template has been created.";

exit 0;

;;

5)

doas apk add nfs-utils

if [ $? != 0 ]
then

cat <<'EOF';
***************************************************
*Error! Packages could not be installed. Aborting.*
***************************************************
EOF

exit 2;

fi

if [ -z "/srv/nfs" ]
then

#Make directory to host NFS Shares.
mkdir -p /srv/nfs;

fi


doas cat <<'EOF' > /etc/exports;
#======================================================
# /etc/exports
#
# See exports(5) for a description.

# use exportfs -arv to reread


#======================================================
#Examples:
#/export                IP address/IP network(rw,no_root_squash)

#Single host
#/srv/nfs/foobar        10.0.0.132(rw,no_root_squash)

#Range of hosts
#/srv/nfs/foobar        10.0.0.1*(rw,no_root_squash)

#All hosts on a network
#/srv/nfs/foobar        10.0.0.0/24(rw,no_root_squash)

#Any IP address on any network
#/srv/nfs/foobar        *(rw,no_root_squash)


#======================================================
#NFS shares

#/srv/tftp               10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash,crossmnt,nohide,insecure)

#======================================================
EOF

echo "";
echo "Custom exports template has been generated and stored in /etc/exports.";
echo "";

#Starts NFS service and adds it to the default level runtime
doas service nfs start;
doas rc-update add nfs runlevel;

echo "Process completed successfully! NFS services have been installed and added to system startup. Custom configuration template has been created.";

exit 0;

;;

6)

doas apk add hostapd

if [ $? != 0 ]
then

cat <<'EOF';
***************************************************
*Error! Packages could not be installed. Aborting.*
***************************************************
EOF

exit 2;

fi


doas cat <<'EOF' > "/tmp/hostapd_custom.conf";
#======================================================
#Settings are set for max security by default.
#They may not be compatible with all wireless NIC's.

# "g" simply means 2.4GHz band
hw_mode=a

# 802.11n support
#ieee80211n=1

# the channel to use
channel=0

# QoS support, also required for full speed on 802.11n/ac/ax
#wmm_enabled=1

# the name of the AP
ssid=my_wifi

# 1=wpa, 2=wep, 3=both
auth_algs=1

# WPA2 only
wpa=2

wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=P@$5w0rd!
#bridge=br0


#======================================================

EOF


#Creates custom hostapd.conf file and cleans up temp files used to create it.
doas cp -f /etc/hostapd/hostapd.conf -t /tmp;
cat /tmp/hostapd_custom.conf /tmp/hostapd.conf > /tmp/new_custom_hostapd.conf;
doas mv -f /tmp/new_custom_hostapd.conf -t /etc/hostapd/hostapd.conf;
rm -Rf /tmp/*;


echo "";
echo "Custom hostapd.conf template has been generated and stored in /etc/hostapd/hostapd.conf.";
echo "";

#Starts Hostapd service and adds it to the default level runtime
doas service hostapd start;
doas rc-update add hostapd runlevel;

echo "Process completed successfully! Hostapd services have been installed and added to system startup. Custom configuration template has been created.";

exit 0;

;;

7)

doas apk add docker

if [ $? != 0 ]
then

cat <<'EOF';
***************************************************
*Error! Packages could not be installed. Aborting.*
***************************************************
EOF

exit 2;

fi

if [ -z "/srv/docker" ]
then

#Make directory to host docker apps and house images.
mkdir -p /srv/docker;

fi

;;

e)

exit 0;

;;

*)

cat <<'EOF'


****************
*Invalid option*
****************

EOF

exit 1;

;;

esac