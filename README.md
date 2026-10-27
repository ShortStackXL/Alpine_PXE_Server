# Alpine_PXE_Server
Alpine Linux PXE/Net Boot Lab Report:

Alpine version used on PXE server: x86-64 v3.22.2

(Last Updated: October 20th, 2026)

Author(s): ShortStackXL

DISCLAIMER:

Some information may be out of date or incorrect entirely. This lab report/walkthrough is meant to share some insight on certain networking functions possible with Alpine Linux. Never run any scripts without first inspecting them and ensuring you know EXACTLY what they are supposed to do.

============================================

Table of Contents:

1) Preface
2) Overview
3) Requirements
4) Setup
 a) Netboot Method (Internet)
 b) HTTP Server Method (Local Net)
5) Troubleshooting
6) Closing Statements
7) Known Issues
8) Appendix

============================================

Preface:

This is a small home lab project I had always wanted to attempt to better understand PXE, servers, and Linux boot processes. I am a student studying networking that wanted to contribute what I learned on this project back into the community for anyone else who wants to setup their own PXE boot server at home. Hopefully by reading this, you can avoid some of the setbacks that I had endured while trying to figure this process out. In the minimalistic spirit of Alpine Linux, this walkthrough has been reduced to the bare minimum to save you time and computing resources. Once you get it up and running, you can customize your server to your heart's content. Any input or corrections to better streamline this process would be much appreciated. I have included many of the commands used in this walkthrough, but I have also included my shell script to automate the process along with other one touch server service setups to streamline deployments.

============================================

Overview:

In this document, you will find everything you need to run a minimalistic PXE boot server in a home or small business environment. All required packages, steps, configurations, resources, and needed software will be included in this document or within a compressed gzip file along with this document. When you have finished reading, you should be able to boot Alpine Linux (and possibly other operating systems) on virtual or physical machines via your local network. This will allow you to run the system diskless or give you the option to install to the local machine. For this project, I used Alpine Linux for both the server and client machines. To minimize the amount of packages required, I used DNSmasq for the TFTP and DHCP services and PXElinux/Syslinux for the bootloader, but other packages or bootloaders can be used if preferred. I was able to have some success with the Limine bootloader, but I preferred PXELinux.

============================================

Requirements:

Client Requirements:

-Internet access or a local HTTP server with all needed packages to install alpine and desired packages
-PXE-compliant network interface card (NIC)
-Virtual or physical hardware (minimums below)
    -BIOS or UEFI
    -1 CPU core
    -256 MB of RAM

Server Requirements:

-Alpine Linux running live, diskless, or installed on server
-TFTP service
-DHCP service
-HTTP service (optional)
-BIOS or UEFI PXE-compliant bootloader

Packages Used (in this tutorial):
-DNSmasq
-nginx (optional)
-PXElinux (Syslinux) or preferred PXE compliant bootloader

Alternative Packages:
-Limine Bootloader
-tftp-hpa
-apache
-Busybox

Recommended Additional Packages:
-OpenSSH (for ssh administration and sftp file transfer)

============================================

Setup:

TFTP PXE Boot:

*** All commands are written in Alpine Linux (BusyBox - sh) ***


Step 1:

Download the necessary packages.


sh cmd:

doas apk add dnsmasq syslinux


Step 2:

Create the directory you want to export as the tftp root. This is the directory you will store all files for PXE booting on your server. In this lab, I created a directory simply called 'tftp' off of the /srv directory (in keeping with Linux/UNIX best practices). This will be the root directory for this project. You can name your directory whatever you would like and create it anywhere in your system, but you will need to adjust the following instructions accordingly if you do. Make sure that all files you will need for the boot are read-enabled in this directory (including the directory itself) or your client will fail to receive the files required to boot. I also created another directory called apkovls. This is not necessary for PXE booting, but I included it to store and load APK overlays on boot to create custom booting environments if I so choose to do so.


sh cmd:

mkdir -p /srv/tftp /srv/tftp/BIOS/pxelinux.cfg /srv/tftp/UEFI/pxelinux.cfg /srv/tftp/Images /srv/tftp/apkovls

touch /srv/tftp/default

doas chmod -Rv 755 /srv/tftp


Step 3:

After you create the directories in step 2, make symlinks for the /srv/tftp/Images, /srv/tftp/apkovls, and /srv/tftp/default directories/files and copy them into the /srv/tftp/BIOS, /srv/tftp/UEFI, /srv/tftp/BIOS/pxelinux.cfg, and /srv/tftp/UEFI/pxelinux.cfg directories respectively. This will save space on your server, minimize errors, and minimize administration hassles by allowing your bootloader to traverse back up the filesystem tree to access a single set of images and configuration files.

NOTE: The bootloader is served as a binary in the directory specified in /etc/dnsmasq.conf. This means that while the root (/srv/tftp) is shared and served to the client, the bootloader only sees the directories where it was served from and those below it in the tree. The symlinks allow us to redirect the bootloaders higher in the directory structure to use a single set of images and configs to simplify things. You could just put all files in the TFTP root and it would work, I just find this simplifies administration in the long run.


sh cmd:

ln -sv /srv/tftp/Images /srv/tftp/BIOS/Images
ln -sv /srv/tftp/apkovls /srv/tftp/BIOS/apkovls
ln -sv /srv/tftp/default /srv/tftp/BIOS/pxelinux.cfg/default

cp -f /srv/tftp/BIOS/Images /srv/tftp/BIOS/apkovls -t /srv/tftp/UEFI
cp -f /srv/tftp/BIOS/pxelinux.cfg/default -t /srv/tftp/UEFI/pxelinux.cfg/default


Step 4:

Download the Alpine Linux Netboot gzip for your desired architecture. In this example, I am downloading the 32-bit and 64-bit Netboot editions (version 3.24.2), but choose the version that works for you. After it has downloaded, extract the contents to a new directory with the name of the operating system. After this is completed you should have 5 files. A System map, a Config file, the Linux kernel (vmlinuz-lts/virt), the initial ram filesystem (initramfs-lts/virt), and the module loop (modloop-lts/virt).


sh cmd:

#Downloads Alpine Netboot x86 and uncompresses files into organized image directory
mkdir -p /srv/tftp/Images/Alpine-Netboot-x86
wget https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86/alpine-netboot-3.24.2-x86.tar.gz -O /srv/tftp/Images/Alpine-Netboot-x86
tar -xfv /srv/tftp/Images/Alpine-Netboot-x86/alpine-netboot-3.24.2-x86.tar.gz -C /srv/tftp/Images/Alpine-Netboot-x86
mv -f /srv/tftp/Images/Alpine-Netboot-x86/boot/* -t /srv/tftp/Images/Alpine-Netboot-x86
rm -Rf /srv/tftp/Images/Alpine-Netboot-x86/alpine-netboot-3.24.2-x86.tar.gz /srv/tftp/Images/Alpine-Netboot-x86/boot

#Downloads Alpine Netboot x86_64 and uncompresses files into organized image directory
mkdir -p /srv/tftp/Images/Alpine-Netboot-x86_64
wget https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-netboot-3.24.2-x86_64.tar.gz -O /srv/tftp/Images/Alpine-Netboot-x86_64
tar -xfv /srv/tftp/Images/Alpine-Netboot-x86_64/alpine-netboot-3.24.2-x86_64.tar.gz -C /srv/tftp/Images/Alpine-Netboot-x86_64
mv -f /srv/tftp/Images/Alpine-Netboot-x86_64/boot/* -t /srv/tftp/Images/Alpine-Netboot-x86_64
rm -Rf /srv/tftp/Images/Alpine-Netboot-x86_64/alpine-netboot-3.24.2-x86_64.tar.gz /srv/tftp/Images/Alpine-Netboot-x86_64/boot


Step 5:

Import the necessary boot loaders and libraries needed for the respective bootloader from the /usr/share/syslinux directory. For a BIOS boot, you will need the pxelinux.0 for TFTP capabilities or lpxelinux.0 for ftp/http capabilities. For UEFI, you will need to use the syslinux.efi bootloader located in the /usr/share/syslinux/efi64 directory. Copy your desired bootloader, corresponding ldlinux.* (.e64/.c32), libutil.c32, and menu.c32 files to the respective directories in the /srv/tftp directory you created in step 2. For clarification, I will provide an example below for both BIOS and UEFI setups.

Example:

BIOS Files ---> /tftp/BIOS

    pxelinux.0
    ldlinux.c32
    menu.c32
    libutil.c32


sh cmd:

cp -f /usr/share/syslinux/pxelinux.0 /usr/share/syslinux/ldlinux.c32 /usr/share/syslinux/menu.c32 /usr/share/syslinux/libutil.c32 -t /srv/tftp/BIOS


UEFI Files ---> /tftp/UEFI

    syslinux.efi
    ldlinux.e64
    menu.c32
    libutil.c32

sh cmd:

cp -f /usr/share/syslinux/efi64/syslinux.efi /usr/share/syslinux/efi64/ldlinux.e64 /usr/share/syslinux/efi64/menu.c32 /usr/share/syslinux/efi64/libutil.c32 -t /srv/tftp/UEFI


Step 6:

Configure the /etc/dnsmasq.conf file. This .conf file has most of the options and their explanations commented in the file itself, so I will not be covering all possible options. I will just be giving you the minimum to serve the proper PXE files to boot over the network. I will also link additional sources to help you learn more about DNSmasq and its other configuration options in the appendix section. Below I have included a template with basic options explained. You will need to tailor this template to fit your specific network and desired options. When all configurations are set, ensure the dnsmasq service is running (it's recommended to add this service to runlevel default if this server is a dedicated PXE boot server).


---Template Start---

#DHCP settings:

#The below settings are REQUIRED to administer IP address information for the client

#Range of IPv4 addresses for lease and the time to lease for

dhcp-range=10.0.0.202,10.0.0.210,4h

#Default Gateway

dhcp-option=3, 10.0.0.1

#DNS Servers

dhcp-option=6, 10.0.0.201,75.75.75.75,75.75.76.76

#The below settings are OPTIONAL but helpful if using as a LAN DHCP/BOOTP server on the adjacent network only

local-service

#=====================================

#TFTP settings:

#The below settings are REQUIRED to serve the files via TFTP. The tftp-root option can specify any directory you are using to serve the files. All paths for TFTP/PXE are based off of this as the root. In other words directory /srv/tftp is now seen by the bootloader and client as /. You will see this matters when specifying the dhcp-boot= file paths for PXE boot below.

enable-tftp
tftp-root=/srv/tftp

#The below settings are OPTIONAL but helpful

tftp-no-fail
tftp-no-blocksize


#=====================================

#PXE boot settings:

#Uncomment only one of these options at a time depending on if you want BIOS or UEFI booting

#dhcp-boot=BIOS/pxelinux.0
#dhcp-boot=UEFI/syslinux.efi

---Template End---


sh cmd:

NOTE: The below command is an example taken directly from my personal server .conf file. You can use this one or the one provided above. The one above is more to show the minimum requirements for the lab not an exhaustive list of common configuration options.

#Copies original .conf file to insert template on top of.
doas cp /etc/dnsmasq.conf -t /tmp

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
cat /tmp/dnsmasq_custom.conf /tmp/dnsmasq.conf > /tmp/new_custom_dnsmasq.conf
doas mv -f /tmp/new_custom_dnsmasq.conf -t /etc/dnsmasq.conf
rm -Rf /tmp/*

doas service dnsmasq start
doas rc-update add dnsmasq runlevel



Step 7:

Configure the bootloader config file (/srv/tftp/default). For PXELinux to use this config file, they must be created under a directory called "pxelinux.cfg" and this directory needs to be located in the same directory as the bootloader (pxelinux.0/syslinux.efi). Now you see why we symlinked the default file in the /srv/tftp directory. Like with DNSmasq, there are many cool options you can use with PXELinux with how you can specify specific installs based on MAC addresses, IP addresses, etc, but that is beyond the scope of this tutorial. In this example we will keep it extremely simple and make our own boot menu so the client can decide what image they want to use at boot. If you are interested in reading more about PXELinux boot options and config syntax, I have included a link to the PXELinux webpage in the appendix section. Below I have included a template with basic options explained and a few other boot parameters that can be useful depending on use case.


---Template Start---

#PXE Linux Boot Options

#Defaults to the boot menu and prompts the user for selection of image

DEFAULT menu.c32
PROMPT 0

#Displays the boot menu name and countdown to autoboot option with a 10 second timer

MENU TITLE Boot Menu
MENU AUTOBOOT Launching local OS in # Seconds
TIMEOUT 100

#Local hardware boot option. This is designated the default on timeout

LABEL Local Boot
#Display name is "Local Boot"
    MENU LABEL Local Boot
#This option specifies what entry will be the default loaded on timeout. Can be used on any desired boot option.
    MENU DEFAULT
#Specifies that this option is a local disk boot.
    LOCALBOOT 0

MENU SEPARATOR

#This label is strictly for identifying boot entries. The "MENU LABEL" option is the one that shows on the boot menu.
LABEL Alpine Netboot x86
#Lists the name of the image on boot menu as "Linux Alpine Netboot (x86)"
        MENU LABEL Linux Alpine Netboot (x86)
#Path to the desired kernel
        KERNEL /Images/Alpine-Netboot-x86/vmlinuz-lts
#Path to the InitRD (In this case the initramfs). This could also be specified in the append line if desired.
        INITRD /Images/Alpine-Netboot-x86/initramfs-lts
#Append line passes kernel boot arguements/parameters. The arguements seen here are required for successful netboot. These can be different from distro to distro. The "alpine_repo=" can specify any mirror server repo that is active.
        APPEND ip=dhcp alpine_repo=https://dl-cdn.alpinelinux.org/alpine/v3.23/main,https://dl-cdn.alpinelinux.org/alpine/v3.23/community

MENU SEPARATOR

LABEL Alpine Netboot x86_64
        MENU LABEL Linux Alpine Netboot (x64)
        KERNEL /Images/Alpine-Netboot-x86_64/vmlinuz-lts
        INITRD /Images/Alpine-Netboot-x86_64/initramfs-lts
        APPEND ip=dhcp alpine_repo=https://dl-cdn.alpinelinux.org/alpine/v3.23/main,https://dl-cdn.alpinelinux.org/alpine/v3.23/community

MENU SEPARATOR

#Some of the below options are Alpine specific and others are kernel specific. To find more information please check the links in the appendix section.

#Useful Kernel Boot Parameters
#pkgs=[pkg,pkg,...] ex. nfs-utils,openssh,...
#apkovl=[URL of APK overlay] ex. http://delta.local/testgui.apkovl.tar.gz
#alpine_repo=[URL of Alpine repo]
#init=[path to init process]
#root=[root device] ex. /dev/nfs OR /dev/sda etc...
#nfsroot=[Server IP Addr]:[/full/nfs/path/foo/bar]
#nfsaddrs=[Server IP Addr]:[/full/path/foo/bar] (Deprecated)
#console=[specify console to load upon boot] ex. tty0
#single [for single user mode]
#debug [maximum verbosity for debug info]
#quiet [suppress boot messages]
#modloop=/path/to/modloop-lts
#modules=[loop,squashfs,...]

---Template End---

sh cmd:

NOTE: The below command is an example taken directly from my personal server "default" file. You can use this one or the one provided above. I wanted to show this one to show how a local HTTP server can be used as the package repository on start up to deliver select packages. The one above is more to show the minimum requirements for the lab not an exhaustive list of common configuration options.

#Copies template information into the default conf file then saves and quits.

cat <<'EOF' > /srv/tftp/default
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



#This is just to ensure all files needed are read and execute enabled.
doas chmod -Rv 755 /srv/tftp



Step 8:

Make all final checks. Ensure all necessary services are running and enabled. Ensure all configurations and file paths are correct. Ensure your client device is configured to PXE boot. Assuming everything works as expected, you should be able to boot into Alpine Linux over your LAN. From here you can install it to a local disk or just use it live. If you have any issues, I have included a comprehensive list of troubleshooting tips below (many of which I had dealt with myself). Below is a final layout of how the directory tree should look when all is said and done.

/srv/tftp/
├── BIOS/
│   ├── ldlinux.c32
│   ├── menu.c32
│   ├── pxelinux.0
│   ├── pxelinux.cfg/
│   │   └── default (symlink -> /tftp/default)
│   ├── Images (symlink -> /tftp/Images)
│   └── apkovls (symlink -> /tftp/apkovls)
├── UEFI/
│   ├── ldlinux.e64
│   ├── menu.c32
│   ├── syslinux.efi
│   ├── pxelinux.cfg/
│   │   └── default (symlink -> /tftp/default)
│   ├── Images (symlink -> /tftp/Images)
│   └── apkovls (symlink -> /tftp/apkovls)
├── Images/
│   └── Alpine-Netboot-x86/
│       ├── vmlinuz-lts
│       ├── initramfs-lts
│       └── ...
└── default (The "Master" config file)



Local HTTP server PXE Install:

If you would like to install all necessary packages and serve them to your client without the use of the internet, you must setup an HTTP/HTTPS server that is accessible to the client. I will not get into how to setup and serve files on your server in this walkthrough. Doing so would take too long and there are many free HTTP server engines out there with their own documentation. If anyone would like a more in depth look at this method please let me know and I would be happy to write a more detailed report on what I know about using HTTP to serve packages. Below are some simple steps to get started and if you need additional help setting up the repository, the Alpine wiki has a lot of useful information.

Step 1:

Download any packages you would like to have installed upon boot. You can do this in a variety of ways but the simplest is to use the Alpine Package Keeper to fetch packages and copy them to where your server serves files from. Another way to download most packages is to download the extended version of Alpine from the Alpine website and copy all packages from the download into your local repository (or atleast the base Alpine install pkgs). It will contain a good majority of packages most people would need so its a faster way to get packages if you want a more flexible option.

sh cmd:

doas apk fetch <pkg>


Step 2:

Add a file named .boot_repository to the root of the file path that will serve the packages. This will signal the root of the repository to APK when installing packages. In that directory you can list any architectures you want to serve packages for (in accordance with the Alpine repo schema) and this will allow APK to automatically adjust the required architecture depending on what version of Alpine is making the request. I will include an example of my own to help clear up any confusion. I just copied the packages from the extended ISO installer image and dropped it into my server for ease of use since it is already setup correctly but you can customize it however you would like. Also make sure you include the 'APKINDEX.tar.gz' file as well. This will be needed to help APK find necessary packages and dependencies. To use this repo, just add your server's URL to the 'alpine_repo=' boot parameter and it will query it when looking for packages. You can also use the 'pkgs=' boot parameter or the 'apkovl=' boot parameter to automatically install packages on boot. To find out more about APK overlays (which are super useful with PXE booting and diskless clients) check out the Alpine Wiki.

Example:

alpine_repo=http://<IP-address>/file/path/to/repo

alpine_repo=http://10.0.0.20/apks

apks/
├── .boot_repository
├── x86/
│   ├── musl-1.2.4-r2.apk
│   ├── busybox-1.36.1-r2.apk
│   └── APKINDEX.tar.gz
└── x86_64/
    ├── musl-1.2.4-r2.apk
    ├── busybox-1.36.1-r2.apk
    └── APKINDEX.tar.gz

#The below boot parameters will need to be added to the "APPEND" line in your "default" file to use them

pkgs=[pkgs,...]

apkovl=http://<IP-address>/file/path/to/apkovl.tar.gz 

***apkovl can only be used with HTTP, HTTPS, or FTP. For more info check the Alpine Wiki under 'Diskless Mode'.

I am still experimenting with this so all information in this section may not be 100% correct. Always read the proper documentation. This is just my experience up until this point. I always include a plethora of other mirrors in case my webserver has issues serving packages, this way there are redundant repositories.

============================================

Troubleshooting:

Here are some helpful tips if you run into issues booting.

Issues Finding PXE Server:

***If clients don't receive any kind of IP addressing, this would be the best place to start.

-Check to make sure all connections (both physical and virtual) are properly configured.
    -Check that ethernet cables are plugged into NIC.
    -Check that NIC's are not disabled in the PXE server OS.
    -Ping known online hosts on your local network to ensure connectivity between server and clients on the LAN.

-Ensure that your DHCP service is running and configured properly.

-Ensure client is not receiving DHCP offers from other DHCP servers on your network.

-Ensure your network connection is fast enough to receive the needed files.

    ***Although rare, it can happen when using wi-fi instead of ethernet.


Booting Issues:

-Make sure the TFTP directory root and files are read-enabled.

-Ensure all necessary files are accessible and included in the directory. Check for missing *.c32 files and ensure all files are read-enabled.

-Make sure the configurations for your tftp server are properly configured and all file paths point to the needed files.

-Ensure clients are configured to boot using the network adapter.


HTTP Server Issues:

-Ensure all repo URL's are correct.

-Ensure packages are in your repo along with an updated index file.

============================================

Closing Statements:

In the future, I intend to explore options using NFS and HTTP on my LAN to download and install the operating system files. If I am successful, I will update this repository and post any findings. I really enjoyed this project and really hope others will contribute and ask questions to make this process easier in the future for any aspiring homelabbers or I.T. professionals. Thank you for checking out my walkthrough and I hope this can serve as a good starting point for anyone interested in Alpine or Linux/UNIX systems or PXE booting.

============================================

Known Issues:

-EFI on Gen 2 Hyper-V VM's and other virtualization software have an issue where they will load the bootloader and the kernel but will fail during/after the initramfs is loaded.

============================================

Appendix:

https://www.alpinelinux.org/

***Alpine Linux website (Includes tutorials, troubleshooting, news, downloads, wikis and more for Alpine Linux.)

https://mirrors.alpinelinux.org/

***Information on all repository mirrors for Alpine Linux

https://pkgs.alpinelinux.org/packages

***Information on all Alpine Linux packages

https://wiki.alpinelinux.org/wiki/OpenRC

***OpenRC system service commands

https://wiki.syslinux.org/wiki/index.php?title=PXELINUX

***Information related to PXELinux and its configuration options

https://www.kernel.org/doc/html/v4.14/admin-guide/kernel-parameters.html

***Information on boot parameters for the Linux kernel

https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html

***Information on DNSmasq configurations

https://nginx.org/en/docs/

***Information on nginx if using the HTTP method

https://wiki.alpinelinux.org/wiki/Diskless_Mode#Apkovl

***Information on APK overlays

https://wiki.alpinelinux.org/wiki/Alpine_local_backup

***Information on the Local Backup Utility (for use with APK Overlays and diskless setups)

============================================
