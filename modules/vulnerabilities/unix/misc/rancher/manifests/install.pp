class rancher::install {
  Exec {
    path => ['/bin', '/usr/bin', '/usr/local/bin', '/sbin', '/usr/sbin']
  }

  ensure_packages(['apt-transport-https', 'ca-certificates', 'curl', 'gnupg2', 'software-properties-common'])

  exec {'remove-all-containers':
    command => 'docker stop $(docker ps -a -q); docker rm $(docker ps -qa)'
  } ->
  docker::run {'rancher-server':
    image => 'rancher/server',
    ports => ['8080:8080'],
    extra_parameters => '--restart=unless-stopped',
  } ->
  exec {'wait-for-rancher-server':
    command => 'sleep 360',
    timeout => 365,
  } ->
  file {'/root/setup-rancher.py':
    source => 'puppet:///modules/rancher/setup-rancher.py',
    mode => '0755',
  } ->
  exec {'configure-rancher':
    command => 'python3 /root/setup-rancher.py',
    environment => [],
  } ->
  docker::image {'alpine':
    image_tag => 'latest',
  } ->
  exec {'wait-for-rancher-host-agent':
    command => 'sleep 60',
    timeout => 65,
  }
}
