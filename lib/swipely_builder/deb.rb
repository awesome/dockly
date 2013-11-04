require 'fpm'

class SwipelyBuilder::Deb
  include DSL::DSL
  include DSL::Logger::Mixin

  logger_prefix '[builder deb]'
  dsl_attribute :package_name, :version, :release, :arch, :build_dir,
                :pre_install, :post_install, :pre_uninstall, :post_uninstall,
                :s3_bucket, :files
  dsl_class_attribute :docker, SwipelyBuilder::Docker
  dsl_class_attribute :foreman, SwipelyBuilder::Foreman

  default_value :version, '0.0'
  default_value :release, '0'
  default_value :arch, 'x86_64'
  default_value :build_dir, 'build/deb'
  default_value :files, []

  def file(source, destination)
    @files << { :source => source, :destination => destination }
  end

  def create_package!
    ensure_present! :build_dir
    FileUtils.mkdir_p(build_dir)
    FileUtils.rm(build_path) if File.exist?(build_path)
    debug "exporting #{package_name} to #{build_path}"
    build_package
    if @deb_package
      @deb_package.output(build_path)
      info "exported #{package_name} to #{build_path}"
    end
  ensure
    @dir_package.cleanup if @dir_package
    @deb_package.cleanup if @deb_package
  end

  def build
    info "creating package"
    create_package!
    info "uploading to s3"
    upload_to_s3
  end

  def build_path
    ensure_present! :build_dir
    "#{build_dir}/#{output_filename}"
  end

  def exists?
    debug "#{name}: checking for package: #{s3_url}"
    SwipelyBuilder::AWS.s3.head_object(s3_bucket, s3_object_name)
    info "#{name}: found package: #{s3_url}"
    true
  rescue
    info "#{name}: could not find package: " +
         "#{s3_url}"
    false
  end

  def upload_to_s3
    return if s3_bucket.nil?
    create_package! unless File.exist?(build_path)
    info "uploading package to s3"
    SwipelyBuilder::AWS.s3.put_bucket(s3_bucket) rescue nil
    SwipelyBuilder::AWS.s3.put_object(s3_bucket, s3_object_name, File.new(build_path))
  end

  def s3_url
    "s3://#{s3_bucket}/#{s3_object_name}"
  end

  def s3_object_name
    "#{package_name}/#{SwipelyBuilder::Util.git_sha}/#{output_filename}"
  end

  def output_filename
    "#{package_name}_#{version}.#{release}_#{arch}.deb"
  end

private
  def build_package
    ensure_present! :package_name, :version, :release, :arch

    info "building #{package_name}"
    @dir_package = FPM::Package::Dir.new
    add_docker(@dir_package)
    add_foreman(@dir_package)
    add_files(@dir_package)

    debug "converting to deb"
    @deb_package = @dir_package.convert(FPM::Package::Deb)

    @deb_package.scripts[:prein] = pre_install
    @deb_package.scripts[:postin] = post_install
    @deb_package.scripts[:preun] = pre_uninstall
    @deb_package.scripts[:postun] = post_uninstall

    @deb_package.name = package_name
    @deb_package.version = version
    @deb_package.iteration = release
    @deb_package.architecture = arch

    info "done building #{package_name}"
  end

  def add_foreman(package)
    return if foreman.nil?
    info "adding foreman export"
    foreman.create!
    package.attributes[:prefix] = foreman.init_dir
    Dir.chdir(foreman.build_dir) do
      package.input('.')
    end
    package.attributes[:prefix] = nil
  end

  def add_docker(package)
    return if docker.nil?
    info "adding docker image"
    docker.generate!
    package.attributes[:prefix] = docker.package_dir
    Dir.chdir(File.dirname(docker.tar_path)) do
      package.input(File.basename(docker.tar_path))
    end
    package.attributes[:prefix] = nil
  end

  def add_files(package)
    return if files.empty?
    info "adding files to package"
    files.each do |file|
      package.attributes[:prefix] = file[:destination]
      Dir.chdir(File.dirname(file[:source])) do
        package.input(File.basename(file[:source]))
      end
      package.attributes[:prefix] = nil
    end
  end
end
