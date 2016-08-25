# == Class: linnaeusng
#
# init.pp for linnaeusng puppet module
#
# Author : Hugo van Duijn
#
class linnaeusng (
  $configuredb         = false,
  $coderepo            = 'git@github.com:naturalis/linnaeus_ng.git',
  $repotype            = 'git',
  $repoversion         = 'present',
  $repokey             = undef,
  $repokeyname         = 'githubkey',
  $reposshauth         = true,
  $managerepo          = false,
  $coderoot            = '/var/www/linnaeusng',
  $webdirs             = ['/var/www/linnaeusng',
                          '/var/www/linnaeusng/www',
                          '/var/www/linnaeusng/www/admin',
                          '/var/www/linnaeusng/www/admin/templates',
                          '/var/www/linnaeusng/www/app',
                          '/var/www/linnaeusng/www/app/style',
                          '/var/www/linnaeusng/www/app/templates',
                          '/var/www/linnaeusng/www/shared',
                          '/var/www/linnaeusng/www/shared/media'],
  $rwwebdirs           = ['/var/www/linnaeusng/www/app/templates/templates_c',
                          '/var/www/linnaeusng/www/app/templates/cache',
                          '/var/www/linnaeusng/www/app/style/custom',
                          '/var/www/linnaeusng/www/shared/cache',
                          '/var/www/linnaeusng/www/shared/media/project',
                          '/var/www/linnaeusng/log/',
                          '/var/www/linnaeusng/www/admin/templates/templates_c',
                          '/var/www/linnaeusng/www/admin/templates/cache'],
  $apachegroup         = 'www-data',
  $userDbHost          = 'localhost',
  $userDbName          = 'linnaeusng',
  $userDbPrefix        = undef,
  $userDbCharset       = 'utf8',
  $adminDbHost         = 'localhost',
  $adminDbName         = 'linnaeusng',
  $adminDbPrefix       = undef,
  $adminDbCharset      = 'utf8',
  $mysqlUser           = 'linnaeus_user',
  $mysqlPassword       = 'mysqlpassword',
  $mysqlRootPassword   = 'defaultrootpassword',
  $appVersion          = '1.0.0',
  $cron                = false,
  $instances           = {'linnaeusng.naturalis.nl' => {
                            'serveraliases'   => '*.naturalis.nl',
                            'aliases'         => [{ 'alias' => '/linnaeus_ng', 'path' => '/var/www/linnaeusng/www' }],
                            'docroot'         => '/var/www/linnaeusng',
                            'directories'     => [{ 'path' => '/var/www/linnaeusng', 'options' => '-Indexes +FollowSymLinks +MultiViews', 'allow_override' => 'All' }],
                            'port'            => 80,
                            'serveradmin'     => 'webmaster@linnaeusng.naturalis.nl',
                            'priority'        => 10,
                          },
                          },
# PHP Settings
  $upload_max_filesize  = '15M',
  $max_file_uploads     = '200',
  $post_max_size        = '100M',
) {

  # include concat and mysql
  include concat::setup

  class { 'linnaeusng::database': }

  # install apache
  class { 'apache':
    default_mods  => true,
    mpm_module    => 'prefork',
  }
  include apache::mod::php
  include apache::mod::rewrite

  # install php curl
  php::module { ['curl']: }

  php::ini { '/etc/php5/apache2/php.ini':
    upload_max_filesize       => $upload_max_filesize,
    post_max_size             => $post_max_size,
    max_file_uploads          => $max_file_uploads,
    require                   => Class['apache']
  }

  # Create all virtual hosts from hiera
  class { 'linnaeusng::instances':
    instances     => $instances,
  }

  # Checkout repository
  class { 'linnaeusng::repo':
  }

  # create application specific directories
  file { $webdirs:
    ensure      => 'directory',
    mode        => '0755',
    require     => Class['linnaeusng::repo'],
  }

  file { $rwwebdirs:
    ensure      => 'directory',
    mode        => '0660',
    owner       => 'root',
    group       => $apachegroup,
    require     => File[$webdirs],
  }

  # create config files based on templates.
  file { "${coderoot}/configuration/admin/configuration.php":
    content       => template('linnaeusng/adminconfig.erb'),
    mode          => '0640',
    owner         => 'root',
    group         => $apachegroup,
    require       => File[$webdirs],
  }

  file { "${coderoot}/configuration/app/configuration.php":
    content       => template('linnaeusng/appconfig.erb'),
    mode          => '0640',
    owner         => 'root',
    group         => $apachegroup,
    require       => File[$webdirs],
  }

# insert zoneinfo data into mysql, use trigger file in /opt to ensure the command runs only once.
  exec { 'mysql_tzinfo':
    command       => "/usr/bin/mysql_tzinfo_to_sql /usr/share/zoneinfo | /usr/bin/mysql -u root -p${mysqlRootPassword} mysql > /opt/mysql_tzinfo_to_sql.trigger",
    require       => Class['linnaeusng::database'],
    unless        => '/usr/bin/test -f /opt/mysql_tzinfo_to_sql.trigger'
  }

  if ($cron == true){
    $randomcron = fqdn_rand(30)
    cron { 'linnaeus data push':
      command => '/usr/bin/php /var/www/linnaeusng/cron/server-stat-push/linnaeus_data_push.php',
      user    => root,
      minute  => [$randomcron],
      hour    => 0
    }
  }
}