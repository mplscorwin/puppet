# class: phabricator
class phabricator {

    require_package(['python-pygments', 'python3-pygments', 'subversion'])

    git::clone { 'arcanist':
        ensure    => present,
        directory => '/var/arcanist',
        origin    => 'https://github.com/phacility/arcanist.git',
    }

    git::clone { 'phabricator':
        ensure    => present,
        directory => '/var/phabricator',
        origin    => 'https://github.com/phacility/phabricator.git',
    }

    exec { "chk_phab_ext_git_exist":
        command => 'true',
        path    =>  ['/usr/bin', '/usr/sbin', '/bin'],
        onlyif  => 'test ! -d /var/phabricator/src/extensions/.git'
    }

    file {'remove_phab_ext_dir_if_no_git':
        ensure  => absent,
        path    => '/var/phabricator/src/extensions',
        recurse => true,
        purge   => true,
        force   => true,
        require => Exec['chk_phab_ext_git_exist'],
    }

    git::clone { 'phabricator-extensions':
        ensure    => latest,
        directory => '/var/phabricator/src/extensions',
        origin    => 'https://github.com/miraheze/phabricator-extensions.git',
    }

    file { '/var/phab':
        ensure => directory,
        mode   => '0755',
        owner  => 'www-data',
        group  => 'www-data',
    }

    file {'phab-robots-custom':
        ensure => file,
        path   => '/var/phab/robots.txt',
        source => 'puppet:///modules/phabricator/phabrobot.txt',
        mode   => '0755',
        owner  => 'www-data',
        group  => 'www-data',
    }

    file { '/var/phab/repos':
        ensure => directory,
        mode   => '0755',
        owner  => 'www-data',
        group  => 'www-data',
    }

    $module_path = get_module_path($module_name)
    $phab_yaml = loadyaml("${module_path}/data/config.yaml")
    $phab_private = {
        'mysql.pass' => lookup('passwords::db::phabricator'),
    }

    $phab_setting = {
        # smtp
        'cluster.mailers'      => [
            {
                'key'          => 'mirahezebots-smtp',
                'type'         => 'smtp',
                'options'      => {
                    'host'     => 'mail.mirahezebots.org',
                    'port'     => 587,
                    'user'     => 'noreply@mirahezebots.org',
                    'password' => lookup('passwords::mail::phab'),
                    'protocol' => 'tls',
                },
            },
        ],
    }

    $phab_settings = merge($phab_yaml, $phab_private, $phab_setting)

    file { '/var/phabricator/conf/local/local.json':
        ensure  => present,
        content => template('phabricator/local.json.erb'),
        require => Git::Clone['phabricator'],
    }
}
