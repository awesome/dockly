require 'rubygems'
require 'dockly'
require 'clamp'

class Dockly::AbstractCommand < Clamp::Command
  option ['-F', '--file'], 'FILE', 'dockly file to read', :default => 'dockly.rb', :attribute_name => :file

  def execute
    if File.exist?(file)
      Dockly.load_file = file
    else
      raise 'Could not find a dockly file!'
    end
  end
end

class Dockly::BuildCommand < Dockly::AbstractCommand
  parameter 'PACKAGE', 'the name to build the package for', :attribute_name => :package_name
  option ['-f', '--force'], :flag, 'force the package build', :default => false, :attribute_name => :force

  def execute
    super
    if package = Dockly.debs[package_name.to_sym]
      if force? || !package.exists?
        package.build
      else
        puts "Package already exists!"
      end
    end
  end
end

class Dockly::ListCommand < Dockly::AbstractCommand
  def execute
    super
    Dockly.debs.each_with_index do |(name, package), index|
      puts "#{index + 1}. #{name}"
    end
  end
end

class Dockly::BuildCacheCommand < Dockly::AbstractCommand
  parameter 'DOCKER', 'the name of the docker image to build for', :attribute_name => :docker_name
  option ['-l', '--list'], :flag, 'list the build caches', :default => false, :attribute_name => :list
  option ['-L', '--local'], :flag, 'use local build caches', :default => false, :attribute_name => :local

  def execute
    Dockly::BuildCache.model = Dockly::BuildCache::Local
    super
    build_caches = Dockly.docker(docker_name.to_sym).build_cache || []
    raise "No build cache for #{docker_name}" if build_caches.empty?
    if list?
      build_caches.each_with_index do |build_cache, index|
        puts "#{index + 1}. Hash: #{build_cache.hash_command} Build: #{build_cache.build_command}"
      end
    else
      bcs = if local?
        convert_bc_to_local_bc(docker_name)
      else
        build_caches
      end
      bcs.each do |bc|
        bc.execute!
      end
    end
  end
end

class Dockly::Cli < Dockly::AbstractCommand
  subcommand ['build', 'b'], 'Create package', Dockly::BuildCommand
  subcommand ['list', 'l'], 'List packages', Dockly::ListCommand
  subcommand ['build_cache', 'bc'], 'Build Cache commands', Dockly::BuildCacheCommand
end

def convert_bc_to_local_bc(docker_name)
  lbcs = []
  Dockly.docker(docker_name.to_sym).build_cache.each do |bc|
    lbc = Dockly::BuildCache::Local.new! { name bc.name }
    bc.instance_variables.each do |variable|
      lbc.instance_variable_set(variable, bc.instance_variable_get(variable))
    end
    lbcs << lbc
  end
  lbcs
end
