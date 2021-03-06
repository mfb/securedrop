#!/bin/bash
# 
# Requirements:
# 1. 3 updated ubuntu 12.04 servers
# 2. The 'server_keys.tar.gz' file from the viewing_setup.sh script
#
# Usage:
#  ./serverSetup.sh 
#  Then follow the instructions
#
  # Check for root
  function rootCheck {
    if [[ $EUID -ne 0 ]]; then
      echo "This script must be run as root" 1>&2
      exit 1
    fi
  }

  # Download puppet ppa package
  function puppetDownload {
    PUPPETRELEASEDEB="https://apt.puppetlabs.com/puppetlabs-release-precise.deb"
    PUPPETDEBNAME="puppetlabs-release-precise.deb"
    if [ -f /etc/apt/sources.list.d/puppetlabs.list ]; then
      wget $PUPPETRELEASEDEB
      dpkg -i $PUPPETDEBNAME
      apt-get update -y
      rm $PUPPETDEBNAME
    else
      echo 'Puppet ppa is already installed'
    fi
  }

  # If puppet master install puppetmaster required packages 
  function installPuppetMaster {
    apt-get install puppetmaster rubygems sqlite3 libsqlite3-ruby -y 
  }

  # If puppet master install puppet module tool
  function installPuppetModuleTool {
    if ! type -P puppet-module; then
      cd /etc/puppet/modules 
      gem install puppet-module
    else
      echo "Puppet module tool already installed"
    fi
  }

  # If puppet master install rails
  function installRails {
    if [[ $(rails -v) != "Rails 2.2.2" ]]; then
      gem install rails -v 2.2.2
    else
      echo "Rails already installed"
    fi
  }

  # If puppet master install required puppet modules
  function installPuppetModules {
    PUPPETMODULES='puppetlabs-apt puppetlabs-git puppetlabs-stdlib'
    DIR='/etc/puppet/modules'
    cd $DIR
    for PUPPETMODULE in $PUPPETMODULES
    do
      NAME=$(echo $PUPPETMODULE | awk -F "-" '{print $2}')
      if [ ! -d "/etc/puppet/modules/$NAME" ]; then 
        echo "Installing $NAME"
        puppet module install $PUPPETMODULE
      else
        echo "$PUPPETMODULE already installed"
      fi
    done
  }

  #Enable puppet stored configs
  function enablePuppetStoredconfigs {
    if ! grep "thin_storeconfigs" /etc/puppet/puppet.conf; then
      echo "thin_storeconfigs = true" >> /etc/puppet/puppet.conf
    fi

    if ! grep "dbadpter" /etc/puppet/puppet.conf; then
      echo "dbadpter = sqlite3" >> /etc/puppet/puppet.conf
    fi  
  }

  #Install deaddrop files
  function downloadDeaddropFiles {
    cd $CURRENTDIR
    echo ''
    read -p 'Enter the path to the securedrop directory: ' -e -i $CURRENTDIR DEADDROPDIR
    cp -Rfp $DEADDROPDIR/{manifests,modules} /etc/puppet/
  }

  #Download ossec binary
  function downloadOSSECBinary {
    cd $CURRENTDIR
    echo ''
    read -p 'Download OSSEC binary from dropbox? (y/n) ' -e -i n DOWNLOADFROMINTERNET

    if [ $DOWNLOADFROMINTERNET == 'n' ]; then
      read -p 'Enter the full path to the OSSEC binary: ' -e -i ~/ossec-binary.tgz OSSECBINARY
    else
      wget https://www.dropbox.com/s/eqdyzpjtpqanknr/ossec-binary.tgz
      OSSECBINARY="ossec-binary.tgz"
    fi
    mv -p $OSSECBINARY /etc/puppet/modules/ossec/files/
  }

  #Unpack and mv the journalist interface's server
  function unpackJournalistSSLFiles {
    cd $CURRENTDIR
    echo ''
    read -p "Enter the full path to the journalist_server_ssl_files.tar.gz file: " -e -i journalist_server_ssl_files.tar.gz SSLFILES
    tar xzf $SSLFILES -C /etc/puppet/modules/deaddrop/files
  }

  #Downlaod webpy
  function downloadWebpy {
    cd $CURRENTDIR
    if [ ! -d '/etc/puppet/modules/deaddrop/files/webpy/web' ]; then
      echo ''
      read -p 'Download webpy from github? (y/n) ' -e -i n DOWNLOADFROMINTERNET

      if [ DOWNLOADFROMINTERNET == 'n' ]; then
        read -p 'Enter the full path to webpy directory: ' -e -i ~/webpy WEBPY
        mv $WEBPY /etc/puppet/deaddrop/files/
      else 
        git clone git://github.com/webpy/webpy.git /etc/puppet/modules/deaddrop/files/webpy
      fi
    fi
  }
   
  # Enter Environment Variables
  function enterEnvironmentVariables {
    DIR="/etc/puppet/manifests"
    echo ''
    echo '##########################################################'
    echo 'You will need to provide the following environment'
    echo 'specific information.'
    echo '- Monitor, Source and Journalist Server IP Address'
    echo '- Monitor, Source and Journalist Servers Fully Qualified'
    echo '    domain names'
    echo '- The internal vpn IP address that the admin will be'
    echo '    connecting from'
    echo '- The internal management IP address of the FW'
    echo '    Local CA usb'
    echo '- The mail server for the OSSEC email alerts to use'
    echo '- The email address to send OSSEC alerts'
    echo '##########################################################'
    echo ''

    cd $DIR
    echo -n "Enter the Monitor server's IP address: "
    read monitor_ip
    awk -v value="'$monitor_ip'" '$1=="$monitor_ip"{$3=value}1' nodes.pp > nodes.pp.tmp && mv nodes.pp.tmp nodes.pp

    echo -n "Enter the Monitor fully qualified domain: "
    read monitor_fqdn
    sed -i "s/monitor_fqdn/$monitor_fqdn/" nodes.pp

    echo -n "Enter the Source Interface server's IP address: "
    read source_ip
    awk -v value="'$source_ip'" '$1=="$source_ip"{$3=value}1' nodes.pp > nodes.pp.tmp && mv nodes.pp.tmp nodes.pp

    echo -n "Enter the Source Interface server's fully qualified domain: "
    read source_fqdn  
    sed -i "s/source_fqdn/$source_fqdn/" nodes.pp

    echo -n "Enter the Journalist Interface server's IP address: "
    read journalist_ip
    awk -v value="'$journalist_ip'" '$1=="$journalist_ip"{$3=value}1' nodes.pp > nodes.pp.tmp && mv nodes.pp.tmp nodes.pp

    echo -n "Enter the Journalist Interface server's fully qualified domain: "
    read journalist_fqdn
    sed -i "s/journalist_fqdn/$journalist_fqdn/" nodes.pp

    echo -n "Enter the VPN's internal IP address for admin: "
    read admin_ip
    awk -v value="'$admin_ip'" '$1=="$admin_ip"{$3=value}1' nodes.pp > nodes.pp.tmp && mv nodes.pp.tmp nodes.pp

    echo -n "Enter the management IP address of the Firewall: "
    read intFWlogs_ip
    awk -v value="'$intFWlogs_ip'" '$1=="$intFWlogs_ip"{$3=value}1' nodes.pp > nodes.pp.tmp && mv nodes.pp.tmp nodes.pp

    echo -n "Enter the mail server for the OSSEC email alerts to use:  "
    read mail_server
    awk -v value="'$mail_server'" '$1=="$mail_server"{$3=value}1' nodes.pp > nodes.pp.tmp && mv nodes.pp.tmp nodes.pp

    echo -n "Enter the email address to send OSSEC alerts:  "
    read ossec_email_to
    awk -v value="'$ossec_email_to'" '$1=="$ossec_email_to"{$3=value}1' nodes.pp > nodes.pp.tmp && mv nodes.pp.tmp nodes.pp

   echo ''
   echo '############################################################'
   echo '#Check the values entered                                  #'
   echo '############################################################'
   echo ''
   cat $DIR/nodes.pp
   echo ''
   echo -n 'Are these okay (y/n): '
   read answer
   case $answer in
     "y")
       main
       ;;
     "n")
       enterEnvironmentVariables
       ;;
     *)
       echo 'invalid entry'
       enterEnvironmentVariables
       ;;
   esac  
  }

  # Install puppet on the source and jouranlist servers 
  function installAgents {
    DIR='/etc/puppet/manifests'
    cd $DIR
    echo ''
    echo ''
    echo '########################################################'
    echo 'This will install and configure puppet on the source and'
    echo 'journalist servers using the IP addresses provided'
    echo '########################################################'
    echo ''
    echo -n 'What is your username on the Source and Journalist server? '
    read REMOTEUSER
    SOURCE=$(awk '{if ($1=="$source_ip") print $3;}' nodes.pp | sed "s/'//g")
    JOURNALIST=$(awk '{if ($1=="$journalist_ip") print $3;}' nodes.pp | sed "s/'//g")
    MONITOR=$(awk '{if ($1=="$monitor_ip") print $3;}' nodes.pp | sed "s/'//g") 
    AGENTS="$SOURCE $JOURNALIST"

    awk '$1=="127.0.0.1"{$3="puppet"}1' /etc/hosts > /etc/hosts.tmp && mv /etc/hosts.tmp /etc/hosts
    for agent in $AGENTS
    do
    echo ''
    echo '#######################################################'
    echo "ssh to $agent as $REMOTEUSER"
    echo '#######################################################'
    echo ''

    ssh -t -t $REMOTEUSER@$agent "sudo /bin/sh -c 'echo "$MONITOR puppet" >> /etc/hosts; wget "http://apt.puppetlabs.com/puppetlabs-release-precise.deb"; dpkg -i "puppetlabs-release-precise.deb"; apt-get update; apt-get install puppet -y; puppet agent -t'"
    done

    echo ''
    echo '#######################################################'
    echo 'Agents are installed sign the agent certs on the puppet'
    echo 'master'
    echo '#######################################################'
    echo ''
  }
 
  #Sign All Certs
  function signAllCerts {
    echo ''
    echo '########################################################'
    echo 'This will sign all the waiting agent certs on the puppet'
    echo 'master'
    echo '########################################################'
    puppetca --sign --all
  }

  #run puppet manifests in correct order
  function runPuppetManifests {
    DIR='/etc/puppet/manifests/'
    cd $DIR
    SOURCE=$(awk '{if ($1=="$source_ip") print $3;}' nodes.pp | sed "s/'//g")
    JOURNALIST=$(awk '{if ($1=="$journalist_ip") print $3;}' nodes.pp | sed "s/'//g")
    AGENTS="$SOURCE $JOURNALIST"
    echo ''
    echo '##########################################'
    echo 'Running puppet manifests on monitor server'
    echo '##########################################'
    echo ''
    service puppetmaster restart
    puppet agent -t
    echo -n 'What is your username on the Source and Journalist server? '
    read REMOTEUSER
    for agent in $AGENTS
    do
    echo "ssh to $agent as $REMOTEUSER"
    ssh -t -t $REMOTEUSER@$agent "sudo /bin/sh -c 'service puppet restart; puppet agent -t'"
    done
  }

  #Main
  function main {
    CURRENTDIR=`pwd`
    rootCheck

    echo ''
    echo '############################################################'
    echo 'Expects for the following to be copied to local dir'
    echo 'Journalist interface ssl certs created on the Local CA usb'
    echo 'Application gpg keys created on the SVS usb'
    echo 'The remaining steps will install puppet run the manifests'
    echo '(1) Install puppetmaster'
    echo '(2) Enter environment information'
    echo '(3) Install puppet agent on source and journalist interface'
    echo '(4) Sign agent certs'
    echo '(5) Run puppet manifests'
    echo '(6) Clean up puppet and install files'
    echo '(7) Apply GRSECURITY lock'
    echo '(0) quit'
    echo '###########################################################'
    echo ''
    echo -n 'Enter your choice (0-7): '
    read option
    case $option in
      #Install puppetmaster
      "1")
        puppetDownload
        installPuppetMaster
        installPuppetModuleTool
        installRails
        installPuppetModules
        enablePuppetStoredconfigs
        downloadDeaddropFiles
        downloadOSSECBinary
        unpackJournalistSSLFiles
        downloadWebpy
        main
        ;;
      #Enter Environment Variables
      "2")
        enterEnvironmentVariables
        main
        ;;
      #Install puppet on agents
      "3")
        installAgents
        main
        ;;
      #Sign certs
      "4")
        signAllCerts
        main
        ;;
      #Run puppet manifests monitor -> source -> journalist
      "5")
        runPuppetManifests
        main
        ;;
      #After installation confirmed successfull cleanup unneeded
      #programs and files
      "6")
        ;;
      #Steps to apply grsec lock
      "7")
        ;;
      "0")
        exit
        ;;
      *) echo invalid options;;
    esac
  }
main

#end
exit0
