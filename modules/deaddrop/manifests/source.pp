class deaddrop::source{
  user { 'www-data' :
    home => '/var/www',
  }

  file { '/var/www' :
    ensure => directory,
    owner => 'root',
    group => 'root',
  }

  file { '/var/www/.ssh' :
    ensure => directory,
    owner => 'www-data',
    group => 'www-data',
  }

  exec { 'ecdsa_hosts':
    path    => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ],
    command => "sed -i 's/ssh-rsa/ecdsa-sha2-nistp256/g' /var/www/.ssh/known_hosts",
    user    => 'root',
    subscribe => Exec['cp_ssh_hosts'],
  }

  file { 'known_hosts':
    ensure => present,
    path   => '/var/www/.ssh/known_hosts',
    owner  => 'www-data',
    group  => 'www-data',
  }

  ssh::auth::client { "www-data": 
    home     => "/var/www",
    require  => File['/var/www/.ssh'],
    user     => 'www-data',
    group    => 'www-data',
    notify   => Exec['cp_ssh_hosts'],
  }

  exec { 'cp_ssh_hosts':
    path    => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ],
    command => 'cp /etc/ssh/ssh_known_hosts /var/www/.ssh/known_hosts',
    user    => 'root',
    group   => 'root',
  }

  apt::key { "tor":
    key        => "886DDD89",
    key_server => "keys.gnupg.net",
  }

  apt::source { "tor":
    location          => "http://deb.torproject.org/torproject.org",
    release           => "precise",
    repos             => "main",
    required_packages => "deb.torproject.org-keyring",
    key               => "886DDD89",
    key_server        => "keys.gnupg.net",
    before            => Package["tor"],
  }

  package { 'tor':
    ensure => "installed",
  }

  file { '/etc/tor/torrc':
    ensure  => file,
    source  => "puppet:///modules/deaddrop/torrc",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package["tor"],
  }

  service { 'tor':
    ensure     => running,
    hasrestart => true,
    hasstatus  => true,
    subscribe  => File['/etc/tor/torrc'],
    require    => Package['tor'],
  }

  exec { 'passwd -l debian-tor':
    path    => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ],
    user    => 'root',
    group   => 'root',
    require => Package["tor"],
  }

##### Install python_gnupg #####
  package { 'python-setuptools': ensure => 'installed', } 

  exec { 'easy_install https://python-gnupg.googlecode.com/files/python-gnupg-0.2.7.tar.gz':
    cwd     => $deaddrop_home,
    path    => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ],
    user    => 'root',
    group   => 'root',
    require => Package["python-setuptools"],
    unless  => "ls /usr/local/lib/python2.7/dist-packages/python_gnupg-0.2.7-py2.7.egg",
  }
##### Install Apache #####
  package { 'apache2-mpm-worker':
    ensure => installed,
    notify => Exec["a2dissite $default_sites"]
  }

  package { 'libapache2-mod-wsgi':
    ensure => installed, 
    require => Package['apache2-mpm-worker'],
    notify  => Exec["a2enmod $enable_mods"],
  }

##### Disable unneeded apache modules #####
  exec { "a2enmod $enable_mods":
    path        => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ],
    user        => 'root',
    group       => 'root',
    logoutput   => 'true',
    subscribe   => Package['libapache2-mod-wsgi'],
    refreshonly => true,
  }

  exec { "a2dismod $disabled_mods":
    path        => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ],
    user        => 'root',
    group       => 'root',
    logoutput   => 'true',
    subscribe   => Package['apache2-mpm-worker'],
    refreshonly => true,
  }

##### configure redirect and ssl vhosts #####
  file { "$source_ip":
    path    => '/etc/apache2/sites-enabled/source',
    owner   => 'root',
    group   => 'root',
    content => template("deaddrop/vhost-deaddrop.conf.erb"),
    require => Package['apache2-mpm-worker'],
  }

##### configure apache config files #####
  file { '/var/www/index.html':
    ensure  => 'absent',
    require => Package['apache2-mpm-worker'],
  }

  file { '/etc/apache2/sites-available/default-ssl':
    ensure  => 'absent',
    require => Package['apache2-mpm-worker'],
   }

  file { '/etc/apache2/sites-available/default':
    ensure  => 'absent',
    require => Package['apache2-mpm-worker'],
  }

  exec { "a2dissite $default_sites":
    path        => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ],
    user        => 'root',
    group       => 'root',
    subscribe   => Package['apache2-mpm-worker'],
    refreshonly => true,
  }

  file { 'ports.conf':
    ensure  => file,
    path    => '/etc/apache2/ports.conf',
    content => template("deaddrop/ports.conf.erb"),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['apache2-mpm-worker'],
  }

  file { 'apache2.conf':
   ensure   => file,
    path    => '/etc/apache2/apache2.conf',
    content => template("deaddrop/apache2.conf.erb"),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['apache2-mpm-worker'],
  }

  file { 'security':
    ensure  => file,
    path    => '/etc/apache2/conf.d/security',
    content => template("deaddrop/security.erb"),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['apache2-mpm-worker'],
  }

##### Copy the application file #####
  file { "$deaddrop_home":
    ensure  => directory,
    recurse => true,
    owner   => $apache_user,
    group   => $apache_user,
    mode    => '0600',
    source  => "puppet:///modules/deaddrop/deaddrop",
    before  => File["$deaddrop_home/store"],
  }

  file {"$deaddrop_home/store":
    ensure => directory,
    owner  => $apache_user,
    group  => $apache_user,
    mode   => "0700",
    before => File["$deaddrop_home/keys"],
  }

  file {"$deaddrop_home/keys":
    ensure => directory,
    owner  => $apache_user,
    group  => $apache_user,
    mode   => '0700',
    before => File["$deaddrop_home/config.py"],
  }

  file { "$deaddrop_home/config.py":
    ensure  => file,
    owner   => $apache_user,
    group   => $apache_user,
    mode    => '0600',
    content => template("deaddrop/config.py.erb"),
    before  => File["$deaddrop_home/web"],
  }

  file { "$deaddrop_home/webpy":
    ensure  => directory,
    recurse => true,
    owner   => $apache_user,
    group   => $apache_user,
    mode    => '0600',
    source  => "puppet:///modules/deaddrop/webpy/",
    before  => File["$deaddrop_home/web"],
  }

  file { "$deaddrop_home/web":
    ensure => 'link',
    target => "$deaddrop_home/webpy/web",
    owner  => $apache_user,
    group  => $apache_user,
  }

  file { '/var/www/deaddrop/static':
    ensure  => directory,
    recurse => true,
    owner   => $apache_user,
    group   => $apache_user,
    mode    => '0700',
    source  => "puppet:///modules/deaddrop/deaddrop/static/",
  }

  package { 'sshfs':
    ensure => installed,
    notify => File['fuse.conf'],
  }

  file { 'fuse.conf':
    ensure => file,
    path => '/etc/fuse.conf',
    source => "puppet:///modules/deaddrop/fuse.conf",
    owner => 'root',
    group => 'root',
  }

  exec { "usermod -a -G fuse $apache_user":
    path  => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ],
    user  => 'root',
    group => 'root',
    require => Package['sshfs'],     
  } 

  file { '/dev/fuse':
    ensure => present,
    owner => 'root',
    group => 'fuse',
    require => Package['sshfs'], 
    before  => Exec['chmod g+rw /dev/fuse'],    
  }

  exec { "chmod g+rw /dev/fuse":
    path   => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ],
    user => 'root',
    group => 'root',
  }

  service { "networking":
    hasrestart => true,
    hasstatus => false,
    restart => "/etc/init.d/networking restart",
    ensure => running,
    provider => upstart,
  }

  mount { "$store_dir":
    notify => Service["networking"],
    ensure => present,
    device => "sshfs#${apache_user}@${journalist_ip}:${store_dir}",
    fstype => 'fuse',
    options => 'comment=sshfs,noauto,users,exec,uid=33,gid=33,allow_other,reconnect,transform_symlinks,BatchMode=yes',
    atboot => no,
    remounts => false,
  }

  mount { "$keys_dir":
    notify => Service["networking"],
    ensure => present,
    device => "sshfs#${apache_user}@${journalist_ip}:${keys_dir}",
    fstype => 'fuse',
    options => 'comment=sshfs,noauto,users,exec,uid=33,gid=33,allow_other,reconnect,transform_symlinks,BatchMode=yes',
    atboot => no,
    remounts => false,
  }
  
  file { '/etc/network/if-up.d/mountsshfs':
    ensure => file,
    source => "puppet:///modules/deaddrop/mountsshfs",
    owner => 'root',
    group => 'root',
    mode => '0750',
  }
 
  file { '/etc/network/if-down.d/umountsshfs':
    ensure => file,
    source => "puppet:///modules/deaddrop/umountsshfs",
    owner => 'root',
    group => 'root',
    mode => '0750',
  }

  file { '/etc/rc.local':
    ensure => file,
    source => "puppet:///modules/deaddrop/rc.local",
    owner => 'root',
    group => 'root',
    mode => '0755',
  }
}
