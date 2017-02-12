#
# @author Alain Mauri
# the class donwloads  two images
# then stores them in a temp file
# creates a photomontage and saves it,
# deleting the temp files

class Csvupload < ActiveRecord::Base
  require 'csv'
  require 'fileutils'
  require  'local_resource'
  require "RMagick"

  # using carrierwave to upload a csv files that
  # contains images urls
  mount_uploader :originalfile, CsvdescriptorUploader

  # constants to create folders needed to store different files
  # FIXME this can be improved using a config.yml file or
  # a file that contains all applicatons constants

  BASE_URL = "product_image/photmontage/"
  TEMP_URL = "product_image/local_temp"
  CSV_URL = "/uploads/csvupload/originalfile/"
  LOGO_URL = Rails.root.join(Rails.public_path).to_s + "/logo/generic_logo.png"

  attr_reader :index

  # basic validation to be sure that the csv file exists
  validates :originalfile, presence: true

  # this method parses the csv file
  # it then creates a background job using delayed job
  # to create a photomontage from url pairs
  def parse_csv(host_url)
    row_array = []

    # index to create one folder for each row
    @index ||= self.id
    CSV.foreach(self.originalfile.current_path) do |row|

      # getting file extension
      # I'm assuming (maybe wrong) that all pairs are of the same type and have
      # the same dimensions
      extension = File.extname(URI.parse(row[1]).path)
      montage_filename = File.basename(URI.parse(row[0]).path,extension) + "_" + File.basename(URI.parse(row[1]).path,extension)

      # creating the filename to save the photomontage
      image_filename_path = self.create_montage_url(montage_filename, extension)

      # background job that creates the photomontage
      self.delay(run_at: 2.minutes.from_now).create_montage(row[0],row[1], image_filename_path)

      # creating the url that will be saved in a csv file
      # so that the photomontage can be downloaded using it
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

  # creates the url of the photomontage
  def create_montage_url(montage_filename, extension)
    create_url(BASE_URL + @index.to_i.to_s)
    return Rails.root.join(Rails.public_path).to_s  + "/" + BASE_URL + @index.to_i.to_s + "/photomontage_#{montage_filename}#{extension}"
  end

  # create the public url of the photomontage
  def create_public_montage_url(montage_filename, extension, host_url)
    host_url + BASE_URL + @index.to_i.to_s + "/photomontage_#{montage_filename}#{extension}"
  end

  # creating the photomontage
  # @param url1 url of the first image
  # @param url2 url of the second image
  # @param url where the photomontage must be saved
  def create_montage(url1,url2, filename)
    # creating all necessary folders
    create_url(TEMP_URL)
    url = Rails.root.join(Rails.public_path).to_s + "/" + TEMP_URL
    begin
        # grabbing remote files and saving them in a temp folder
        file1 = LocalResource::local_resource_from_file(url1,url)
        file2 = LocalResource::local_resource_from_file(url2,url)
        file1.file.close
        file2.file.close

        # Assuming the images have the same dimensions
        img = Magick::Image.read(file1.file.path).first
        img1 = file1.file.path
        img2 = file2.file.path

        # creating an image list
        image_list = Magick::ImageList.new(img1,img2)

        # creating the photomontage
        # FIXME this could be improved in many ways
        # using a configuration file
        # or also creating a user interface where all the params can be chosen
        montage = image_list.montage
        montage = image_list.montage {
            self.geometry = "x606+5.5>"
            self.tile = Magick::Geometry.new(2,1)
            self.background_color = "white"
        }
        final_image = montage.flatten_images
        final_image.write(filename){self.quality=100}

        # creating border
        img = Magick::Image.read(filename).first
        img.resize_to_fit!(img.columns,"789")
        img.border!(5.5,11,"#FFFFFF")

        # whatermarking the image with a logo
        mark = Magick::Image.read(LOGO_URL).first
        img = img.watermark(mark, lightness=1.0, saturation=1.0, gravity=Magick::SouthEastGravity, x_offset=20, y_offset=20)

        # saving the image trying to preserve the original quality
        img.write(filename){self.quality=100}

    rescue => error
        logger.info(" Something bad happened ")
        logger.info(error.message.to_s + " " + error.backtrace.join('\n'))
    ensure
        # deleting temp files
        file1.file.unlink
        file2.file.unlink
    end
  end

  # method that creates a folder if it doesn't exist
  # @param path the path of the folder
  # the new folder is created as a subfolder of rails public one.
  def create_url(path)
    FileUtils.cd(Rails.root.join(Rails.public_path).to_s)
    unless File.directory?(path)
      FileUtils.mkdir_p(path)
    end
  end
end
