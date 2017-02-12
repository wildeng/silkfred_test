class CsvuploadsController < ApplicationController

  before_action :authenticate_user!

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
      host_url = request.protocol + request.host_with_port + "/"
      csvupload.delay.parse_csv(host_url)
      flash[:notice] = "File has been saved, wait 5 minutes for processing"
      redirect_to action: :index
    rescue
      flash[:error] =  "CSV file can't be blank"
      redirect_to action: :new
    end
  end

  private

  def csv_params
    params.require(:csvupload).permit(:description, :originalfile)
  end
end
