#
# @author Alain Mauri
#
# @param uri the url from which a file must be downloaded
# @param temp_path the path to the temp file where the file must be stored
#
#
class LocalResource
  require 'tempfile'

  attr_reader :uri
  attr_reader :temp_path


  def initialize(uri,temp_path)
    @uri ||= uri
    @temp_path ||= temp_path
  end

  # creating an io object
  def io
    @io ||= uri.open
  end

  # reading file encoding type
  def encoding
    io.rewind
    io.read.encoding
  end

  # creating temp file name
  def tmp_filename
    extension = File.extname(uri.path)
    File.basename(uri.path,extension) + extension
  end

  # saving the file to the temp folder
  def file
   @file ||= Tempfile.new(tmp_filename, temp_path, encoding: encoding).tap do |f|
     io.rewind
     f.write(io.read)
     f.close
   end
  end

  # passing an instance of the class
  def self.local_resource_from_file(url,temp_path)
   LocalResource.new(URI::parse(url),temp_path)
  end

end
