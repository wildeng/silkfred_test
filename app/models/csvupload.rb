class Csvupload < ActiveRecord::Base
  require 'csv'
  require 'fileutils'
  require  'local_resource'
  require "RMagick"

  mount_uploader :originalfile, CsvdescriptorUploader
  BASE_URL = "product_image/photmontage/"
  TEMP_URL = "product_image/local_temp"
  CSV_URL = "/uploads/csvupload/originalfile/"
  LOGO_URL = Rails.root.join(Rails.public_path).to_s + "/logo/generic_logo.png"

  attr_reader :index
  validates :originalfile, presence: true

  def parse_csv(host_url)
    row_array = []
    # index to create one folder for each row
    @index ||= self.id
    CSV.foreach(self.originalfile.current_path) do |row|
      extension = File.extname(URI.parse(row[1]).path)
      montage_filename = File.basename(URI.parse(row[0]).path,extension) + "_" + File.basename(URI.parse(row[1]).path,extension)
      image_filename_path = self.create_montage_url(montage_filename, extension)
      self.delay(run_at: 2.minutes.from_now).create_montage(row[0],row[1], image_filename_path)
      local_filename_path = self.create_public_montage_url(montage_filename, extension, host_url)
      row_array << [row[0],row[1], local_filename_path]
      @index +=1
    end
    filepath = CSV_URL + self.id.to_i.to_s + '/'
    filename = 'photomontage_pairs.csv'
    CSV.open(Rails.root.join(Rails.public_path).to_s + filepath + filename, 'wb') do |csv_object|
      row_array.each do |row|
        csv_object << row
      end
    end
    self.photomontage_file = filepath + filename
    self.save
  end

  def create_montage_url(montage_filename, extension)
    create_url(BASE_URL + @index.to_i.to_s)
    return Rails.root.join(Rails.public_path).to_s  + "/" + BASE_URL + @index.to_i.to_s + "/photomontage_#{montage_filename}#{extension}"
  end

  def create_public_montage_url(montage_filename, extension, host_url)
    host_url + BASE_URL + @index.to_i.to_s + "/photomontage_#{montage_filename}#{extension}"
  end

  def create_montage(url1,url2, filename)
    create_url(TEMP_URL)
    url = Rails.root.join(Rails.public_path).to_s + "/" + TEMP_URL
    begin
        file1 = LocalResource::local_resource_from_file(url1,url)
        file2 = LocalResource::local_resource_from_file(url2,url)
        file1.file.close
        file2.file.close
        # Assuming the images have the same dimensions
        img = Magick::Image.read(file1.file.path).first
        #img2 = Magick::Image.from_blob(File.open(file2.file.path).read)[0]
        img1 = file1.file.path
        img2 = file2.file.path
        image_list = Magick::ImageList.new(img1,img2)
        montage = image_list.montage
        montage = image_list.montage {
            self.geometry = "x606+5.5>"
            self.tile = Magick::Geometry.new(2,1)
            self.background_color = "white"
        }
        final_image = montage.flatten_images
        final_image.write(filename){self.quality=100}

        img = Magick::Image.read(filename).first
        img.resize_to_fit!(img.columns,"789")
        img.border!(5.5,11,"#FFFFFF")

        mark = Magick::Image.read(LOGO_URL).first
        img = img.watermark(mark, lightness=1.0, saturation=1.0, gravity=Magick::SouthEastGravity, x_offset=20, y_offset=20)

        img.write(filename){self.quality=100}

    rescue => error
        logger.info(" Something bad happened ")
        logger.info(error.message.to_s + " " + error.backtrace.join('\n'))
    ensure
        file1.file.unlink
        file2.file.unlink
    end
  end

  def create_url(path)
    FileUtils.cd(Rails.root.join(Rails.public_path).to_s)
    #dirname = File.dirname(path)
    unless File.directory?(path)
      FileUtils.mkdir_p(path)
    end
  end



  def cur_dir

  end

end
