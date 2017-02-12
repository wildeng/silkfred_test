#
# @author Alain Mauri
# This controller manages the upload of a csv file
# It then delays it's parsing using delayed job gem

class CsvuploadsController < ApplicationController

  before_action :authenticate_user!

  #
  # Index action, it displays all uploaded files
  # and all parsed files
  def index
    @csvuploaded = Csvupload.all
    respond_to do |format|
      format.html
    end
  end

  def new
    @csvupload = Csvupload.new
  end


  def create
    csvupload = Csvupload.new
    csvupload.description = csv_params[:description]
    csvupload.originalfile = csv_params[:originalfile]
    begin
      csvupload.save!
      # retrieving host url to pass it to a method
      # so that it could use it to save
      # photomontage
      host_url = request.protocol + request.host_with_port + "/"
      csvupload.delay(run_at: 5.minutes.from_now).parse_csv(host_url)
      flash[:notice] = "File has been saved processing will be done in background, please come later"
      redirect_to action: :index
    rescue
      flash[:error] =  "CSV file can't be blank"
      redirect_to action: :new
    end
  end

  private
  # strong parameters management
  def csv_params
    params.require(:csvupload).permit(:description, :originalfile)
  end
end
