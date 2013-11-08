[![Gem Version](https://badge.fury.io/rb/dockly.png)](http://badge.fury.io/rb/dockly)
[![Build Status](https://travis-ci.org/swipely/dockly.png?branch=refactor_setup)](https://travis-ci.org/swipely/dockly)
[![Dependency Status](https://gemnasium.com/swipely/dockly.png)](https://gemnasium.com/swipely/dockly)

Dockly
=======

`dockly` is a gem made to ease the pain of packaging an application. For this gem to be useful, quite a few assumptions can be made about your stack:

- You use AWS
- You're deploying to a Debian-based system
- You want to use [Docker](http://docker.io) for process isolation

Although only a specific type of repository may be used, these assumptions allow us to define a simple DSL to describe your repository.

The DSL
-------

The DSL is broken down into multiple objects, all of which conform to a specific format. Each object starts with the name of the section,
followed by a name for the object you're creating, and a block for configuration.

```ruby
docker :test_docker do
  # code here
end
```

Each object has an enumeration of valid attributes. The following code sets the `repository` attribute in a `docker` called `test_docker`:

```ruby
docker :test_docker do
  repository 'an-awesome-name'
end
```

Finally, each object has zero or more valid references to other DSL objects. The following code sets `deb` that references a `docker`:

```ruby
docker :my_docker do
  repository 'my-name'
end

deb :my_deb do
  docker :my_docker
end
```

Below is an alternative syntax that accomplishes the same thing:

```ruby
deb :my_deb do
  docker do
    repository 'my-name'
  end
end
```

`build_cache`
-------------

The `build_cache` DSL is used to prevent rebuilding assets every build and used cached assets.

- `s3_bucket`
    - required: `true`
    - description: the bucket name to download and upload build caches to
- `s3_object_prefix`
    - required: `true`
    - description: the name prepended to the package; allows for namespacing your caches
- `hash_command`
    - required: `true`
    - description: command run inside of the Docker image to determine if the build cache is up to date (eg. `md5sum ... | awk '{ print $1 }'`)
- `build_command`
    - required: `true`
    - description: command run inside of the Docker image when the build cache is out of date
- `output_dir`
    - required: `true`
    - description: where the cache is located in the Docker image filesystem
- `tmp_dir`
    - required: `true`
    - default: `/tmp`
    - description: where the build cache files are stored locally; this should be able to be removed easily since they all exist in S3 as well
- `use_latest`
    - required: `false`
    - default: `false`
    - description: when using S3, will insert the S3 object tagged as latest in your "s3://s3_bucket/s3_object_prefix" before running the build command to quicken build times

`docker`
--------

The `docker` DSL is used to define Docker containers. It has the following attributes:

- `import`
    - required: `true`
    - description: the location (url or S3 path) of the base image to start building from
- `git_archive`:
    - required: `false`
    - default: `nil`
    - description: the relative file path of git repo that should be added to the container
- `build`
    - required: `true`
    - description: aditional Dockerfile commands that you'd like to pass to `docker build`
- `repository`
    - required: `true`
    - default: `'dockly'`
    - description: the repository of the created image
- `name`
    - alias for: `repository`
- `tag`
    - required: `true`
    - description: the tag of the created image
- `build_dir`
    - required: `true`
    - default: `./build/docker`
    - description: the directory of the temporary build files
- `package_dir`
    - required: `true`
    - default: `/opt/docker`
    - description: the location of the created image in the Debian package
- `timeout`
    - required: `true`
    - default: `60`
    - description: the excon timeout for read and write when talking to docker through docker-api
- `build_caches`
    - required: `false`
    - default: `[]`
    - description: a listing of references to build caches to run

In addition to the above attributes, `docker` has the following references:

- `build_cache`
    - required: `false`
    - class: `Dockly::BuildCache`
    - description: a caching system to stop rebuilding/compiling the same files every time

`foreman`
---------

The `foreman` DSL is used to define the foreman export scripts. It has the following attributes:

- `env`
    - description: accepts same arguments as `foreman start --env`
- `procfile`
    - required: `true`
    - default: `'Procfile'`
    - description: the Procfile to use
- `type`
    - required: `true`
    - default: `'upstart'`
    - description: the type of foreman script being defined
- `user`
    - required: `true`
    - default: `'nobody'`
    - description: the user the scripts will run as
- `root_dir`
    - required: `false`
    - default: `'/tmp'`
    - description: set the root directory
- `init_dir`
    - required: `false`
    - default: `'/etc/init'`
    - description: the location of the startup scripts in the Debian package
- `prefix`
    - required: `false`
    - default: `nil`
    - description: a prefix given to each command from foreman.
    must be using https://github.com/adamjt/foreman for this to work

`deb`
-----

The `deb` DSL is used to define Debian packages. It has the following attributes:

- `package_name`
    - required: `true`
    - description: the name of the created package
- `version`
    - required: `true`
    - default: `0.0`
    - description: the version of the created package
- `release`
    - required: `true`
    - default: `0`
    - description: the realese version of the created package
- `arch`
    - required: `true`
    - default: `x86_64`
    - description: the intended architecture of the created package
- `build_dir`
    - required: `true`
    - default: `build/deb`
    - description: the location of the temporary files on the local file system
- `pre_install`, `post_install`, `pre_uninstall`, `post_uninstall`
    - required: `false`
    - default: `nil`
    - description: script hooks for package events
- `s3_bucket`
    - required: `false`
    - default: `nil`
    - description: the s3 bucket the package is uploaded to

In addition to the above attributes, `deb` has the following references:

- `docker`
    - required: `false`
    - default: `nil`
    - class: `Dockly::Docker`
    - description: configuration for an image packaged with the deb
- `foreman`
    - required: `false`
    - default: `nil`
    - class: `Dockly::Foreman`
    - description: any Foreman scripts used in the deb


Demo
===

```ruby
deb :dockly_package do
  package_name 'dockly_package'
  version '1.0'
  release '1'

  docker do
    name :dockly_docker
    import 's3://dockly-bucket-name/base-image.tar.gz'
    git_archive '/app'
    timeout 120

    build_cache do
      s3_bucket "dockly-bucket-name"
      s3_object_prefix "bundle_cache/"
      hash_command "cd /app && ./script/bundle_hash"
      build_command "cd /app && ./script/bundle_package"
      output_dir "/app/vendor/bundle"
      use_latest true
    end

    build <<-EOF
      run cd /app && echo "1.0-1" > VERSION && echo "#{Dockly.git_sha}" >> VERSION
    EOF
    # git_sha is available from Dockly
  end

  foreman do
    name 'dockly'
    procfile 'Procfile'
    prefix 'source /etc/dockly_env '
    log_dir '/data/logs'
    user 'ubuntu'
  end

  s3_bucket 'dockly-bucket-name'
  # ends up in s3://#{s3_bucket}/#{package_name}/#{git_hash}/#{package_name}_#{version}.#{release}_#{arch}.deb
end
```

Copyright (c) 2013 Swipely, Inc. See LICENSE.txt for further details.
