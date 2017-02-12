class LocalResource
  require 'tempfile'

  attr_reader :uri
  attr_reader :temp_path


  def initialize(uri,temp_path)
    @uri ||= uri
    @temp_path ||= temp_path
  end

  def io
    @io ||= uri.open
  end

  def encoding
    io.rewind
    io.read.encoding
  end

  def tmp_filename
    extension = File.extname(uri.path)
    File.basename(uri.path,extension) + extension
  end

  def file
   @file ||= Tempfile.new(tmp_filename, temp_path, encoding: encoding).tap do |f|
     io.rewind
     f.write(io.read)
     f.close
   end
  end

  def self.local_resource_from_file(url,temp_path)
   LocalResource.new(URI::parse(url),temp_path)
  end

  def get_tempfile_path
    return temp_path + "/" + tmp_filename
  end
end
