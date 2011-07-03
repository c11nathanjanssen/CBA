class UsersController < ApplicationController

  load_and_authorize_resource :except => [:hide_notification, :show_notification, :notifications]
  respond_to :html, :js

  def index
    @user_count = User.count
    @users = User.all.reject { |u|
      !can? :read, u
    }.paginate(:page => params[:page],
               :per_page => CONSTANTS['paginate_users_per_page'])

    respond_to do |format|
      format.js
      format.html
    end
  end

  def show
  end

  def geocode
    @user = current_user
    address_attempt = @user.get_ip(request.remote_ip)
    # TODO REMOVE!
    address_attempt = [38.7909, -77.0947] if address_attempt.all? { |a| a == 0 }
    @coords = build_coords(address_attempt)
    district = @user.get_district(address_attempt).first
    @district, @state = district.district, district.us_state
    @lat = params[:lat] || "19.71844"
    @lon = params[:lon] || "-155.095228"
    @zoom = params[:zoom] || "10"
  end

  def district
    user = current_user
    case params[:commit]
      when "Yes"
        coords= Geocoder.coordinates(params[:location])
        districts = user.get_district(coords)
        flash[:method] = :ip_lookup
      when "Submit Address"
        coords = Geocoder.coordinates(build_address(params))
        districts = user.get_district(coords)
        flash[:method] = :address
      when "Submit Zip Code"
        districts = user.get_districts_by_zipcode(params[:zip_code])
        flash[:method] = :zip_lookup
        coords = nil
      else
        districts = nil
        coords = nil
    end
    if districts.nil?
      flash[:notice] = "No addresses found, please refine your answer or try a different method."
      redirect_to users_geocode_path
    elsif districts.count > 1 # then we need to pick a district
      flash[:notice] = "Multiple districts found for #{params[:zip_code]}, please enter your address or a zip+4"
      redirect_to users_geocode_path
    else
      district = districts.first
      @district, @state = district.district, district.us_state
      members = user.get_members(district.members)
      @senior_senator = members[:senior_senator]
      @junior_senator = members[:junior_senator]
      @representative = members[:representative]
      @coords = build_coords(coords, @district)
    end
  end


#  def district_old
#    user = current_user
#    result = user.get_geodata(params)
#    flash[:method] = result[:method]
#    if result[:geo_data].nil? #|| !(result[:geo_data].all? {|r| r.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/)})
#      flash[:notice] = "No addresses found, please refine your answer or try a different method."
#      redirect_to users_geocode_path
#    elsif false #result[:geo_data].address_count > 1
#      @addresses = result[:geo_data].multiple_addresses # wrong !!
#      @address = build_address(params)
#      flash[:notice] = "more than one address found, please pick yours"
#      flash[:multiple_addresses] = true
#    else # they have one address, find the district
#      @district, @state = user.get_and_save_district(result[:geo_data].first, result[:geo_data].last, true)
#      members = user.get_three_members
#      @senior_senator = members[:senior_senator]
#      @junior_senator = members[:junior_senator]
#      @representative = members[:representative]
#    end
#  end

  def save_geocode
    @user = current_user
    # TODO remove old state and district groups
    #@user.polco_groups.where(type: :state).delete_all
    #@user.polco_groups.where(type: :district).delete_all
    # now add exactly two groups
    @senior_senator = Legislator.where(:_id => params[:senior_senator]).first
    @junior_senator = Legislator.where(:_id => params[:junior_senator]).first
    @representative = Legislator.where(:_id => params[:representative]).first
    @user.legislators.push(@junior_senator)
    @user.legislators.push(@senior_senator)
    @user.legislators.push(@representative)
    @user.district = params[:district]
    @user.polco_groups.push(PolcoGroup.where(:name => params[:us_state], :type => :state).first)
    @user.polco_groups.push(PolcoGroup.where(:name => params[:district], :type => :district).first)
    @user.role = :registered # 7 = registered
    # TODO save the zip code + 4 too!
    @user.save!
    # look up bills sponsored by member
  end

  def edit_role
    if is_current_user?(@user)
      redirect_to registrations_path, :alert => t(:you_can_not_change_your_own_role)
    end
  end

  def update_role
    @user.update_attributes!(params[:user])
    redirect_to registrations_path, :notice => t(:role_of_user_updated, :user => @user.name)
  end

  def crop_avatar
    if !@user.new_avatar?
      redirect_to @user, :notice => flash[:notice]
    elsif is_in_crop_mode?
      if @user.update_attributes(params[:user])
        render :show
      else
        redirect_to edit_user_path(@user), :error => @user.errors.map(&:to_s).join("<br />")
      end
    end
  end

  def destroy
    @user.delete
    redirect_to registrations_path,
                :notice => t(:user_deleted)
  end

  # GET /hide_notification/:created_at_as_id
  def show_notification
    if user_signed_in?
      ts = Time.at(params[:id].to_i)
      notification = current_user.user_notifications.where(:created_at => ts).first
      unless notification.nil?
        notification.hidden = false
        current_user.save!
        notice = t(:notification_successfully_shown)
        error = nil
      else
        notice = nil
        error = t(:notification_cannot_be_shown)
      end
      redirect_to :back, :notice => notice, :alert => error
    end
  end

  # GET /hide_notification/:created_at_as_id
  def hide_notification
    if user_signed_in?
      ts = Time.at(params[:id].to_i)
      notification = current_user.user_notifications.where(:created_at => ts).first
      unless notification.nil?
        notification.hidden = true
        current_user.save!
        notice = t(:notification_successfully_hidden)
        error = nil
      else
        notice = nil
        error = t(:notification_cannot_be_hidden)
      end
      redirect_to :back, :notice => notice, :alert => error
    end
  end

  def notifications
    @notifications = current_user.user_notifications.hidden
  end

  def details
    respond_to do |format|
      format.js
      format.html
    end
  end

  private
  def is_in_crop_mode?
    params[:user] &&
        params[:user][:crop_x] && params[:user][:crop_y] &&
        params[:user][:crop_w] && params[:user][:crop_h]
  end

  def build_address(params)
    if params[:zip]
      "#{params[:street_address].strip}, #{params[:city].strip}, #{params[:state].strip}, #{params[:zip].strip}"
    else
      "#{params[:street_address].strip}, #{params[:city].strip}, #{params[:state].strip}"
    end
  end

  def build_coords(input, district_name)
    input = get_district_center(district_name) unless input
    "#{input.first},#{input.last}"
  end

  def get_district_center(district_name)
    coords = {
        "AL05" => [34.5782, -86.7549],
        "AL04" => [34.0793, -86.861],
        "AL06" => [33.4316, -86.8053],
        "AL07" => [32.6606, -87.4622],
        "AL03" => [32.9714, -85.8639],
        "AL02" => [31.9737, -86.0963],
        "AL01" => [31.2947, -87.6862],
        "AKAL" => [59.4545, -153.415],
        "AZ02" => [35.7584, -112.1879],
        "AZ01" => [35.6664, -111.5524],
        "AZ03" => [33.7627, -112.0421],
        "AZ05" => [33.6657, -111.692],
        "AZ04" => [33.4397, -112.0981],
        "AZ06" => [33.349, -111.6459],
        "AZ07" => [33.0613, -112.9024],
        "AZ08" => [32.0616, -110.8169],
        "AR02" => [35.1381, -92.1164],
        "AR03" => [35.7012, -93.5232],
        "AR04" => [34.0629, -92.5476],
        "AR01" => [35.2588, -91.1529],
        "CA04" => [39.3917, -121.0437],
        "CA03" => [38.4468, -120.9425],
        "CA05" => [38.5901, -121.4066],
        "CA01" => [39.6084, -122.8846],
        "CA11" => [37.6513, -121.4787],
        "CA18" => [37.3135, -120.9001],
        "CA25" => [36.2958, -118.3289],
        "CA41" => [34.3452, -116.3699],
        "CA45" => [33.7359, -116.3702],
        "CA51" => [32.8288, -116.1145],
        "CA49" => [33.3184, -117.0196],
        "CA50" => [33.0221, -117.1682],
        "CA52" => [32.866, -116.7616],
        "CA53" => [32.7475, -117.1214],
        "CA02" => [40.1011, -122.401],
        "CA06" => [38.3993, -122.7654],
        "CA07" => [38.1347, -122.1092],
        "CA10" => [38.0062, -121.8989],
        "CA08" => [37.7465, -122.4353],
        "CA09" => [37.7516, -122.1409],
        "CA12" => [37.5803, -122.3758],
        "CA13" => [37.6465, -122.0601],
        "CA14" => [37.2158, -122.0246],
        "CA15" => [37.2319, -121.8763],
        "CA16" => [37.2422, -121.7976],
        "CA21" => [36.7396, -118.8657],
        "CA19" => [37.5277, -120.1123],
        "CA17" => [36.5742, -121.2935],
        "CA20" => [36.1438, -119.8616],
        "CA23" => [34.8153, -120.3379],
        "CA22" => [35.2401, -119.852],
        "CA24" => [34.6656, -119.9317],
        "CA27" => [34.2341, -118.4241],
        "CA26" => [34.1994, -117.9135],
        "CA28" => [34.1763, -118.4177],
        "CA43" => [34.0976, -117.3876],
        "CA29" => [34.1496, -118.168],
        "CA32" => [34.0735, -117.997],
        "CA31" => [34.0764, -118.2519],
        "CA30" => [34.1153, -118.506],
        "CA38" => [34.0113, -117.9787],
        "CA33" => [34.0482, -118.3383],
        "CA34" => [33.9879, -118.185],
        "CA44" => [33.7558, -117.4809],
        "CA36" => [33.8774, -118.3539],
        "CA42" => [33.8411, -117.7698],
        "CA39" => [33.9209, -118.1175],
        "CA37" => [33.8631, -118.2151],
        "CA35" => [33.9489, -118.3236],
        "CA47" => [33.7834, -117.9147],
        "CA46" => [33.6548, -118.1508],
        "CA40" => [33.8272, -117.9205],
        "CA48" => [33.6601, -117.7781],
        "CO04" => [39.5992, -104.3664],
        "CO02" => [40.0124, -105.7144],
        "CO07" => [39.7818, -104.8797],
        "CO01" => [39.7193, -104.9447],
        "CO06" => [39.5345, -104.9286],
        "CO05" => [38.9906, -105.8884],
        "CO03" => [39.1675, -105.9706],
        "CT01" => [41.7242, -72.7807],
        "CT05" => [41.6347, -73.0552],
        "CT02" => [41.5941, -72.4317],
        "CT03" => [41.4098, -72.8728],
        "CT04" => [41.2471, -73.3091],
        "DEAL" => [39.2062, -75.5011],
        "DC98" => [38.8956, -77.0131],
        "FL04" => [30.3317, -82.5043],
        "FL02" => [30.2016, -84.1106],
        "FL01" => [30.651, -86.6723],
        "FL03" => [29.3743, -81.635],
        "FL06" => [29.649, -82.2656],
        "FL24" => [28.7089, -81.1855],
        "FL07" => [29.1002, -81.3478],
        "FL05" => [28.8426, -82.3624],
        "FL08" => [28.7503, -81.6209],
        "FL15" => [28.0951, -81.1437],
        "FL12" => [27.9534, -81.7266],
        "FL11" => [27.804, -82.527],
        "FL09" => [28.072, -82.5024],
        "FL10" => [27.8855, -82.7313],
        "FL13" => [27.3151, -82.3406],
        "FL16" => [27.066, -80.7701],
        "FL23" => [26.5529, -80.2779],
        "FL14" => [26.5298, -81.9752],
        "FL19" => [26.4241, -80.1624],
        "FL22" => [26.4723, -80.1401],
        "FL20" => [26.0541, -80.1931],
        "FL17" => [25.9014, -80.222],
        "FL21" => [25.8383, -80.3233],
        "FL18" => [25.2787, -80.6424],
        "FL25" => [25.5856, -80.8512],
        "GA09" => [34.555, -84.2448],
        "GA06" => [34.0094, -84.4061],
        "GA10" => [34.0206, -83.0968],
        "GA04" => [33.7615, -84.1811],
        "GA13" => [33.6768, -84.4913],
        "GA07" => [33.8934, -83.9102],
        "GA05" => [33.7203, -84.4187],
        "GA08" => [32.5031, -83.4537],
        "GA11" => [33.9786, -84.8229],
        "GA03" => [33.1753, -84.6262],
        "GA12" => [32.6499, -82.239],
        "GA01" => [31.6111, -82.2586],
        "GA02" => [31.9286, -84.4131],
        "HI01" => [21.3795, -157.8804],
        "HI02" => [21.4669, -158.5271],
        "ID01" => [44.8144, -115.6252],
        "ID02" => [44.2339, -114.6933],
        "IL08" => [42.1888, -88.1039],
        "IL16" => [42.1552, -89.372],
        "IL06" => [41.9554, -88.0644],
        "IL07" => [41.8627, -87.715],
        "IL03" => [41.7701, -87.7677],
        "IL13" => [41.7018, -88.0159],
        "IL14" => [41.7637, -89.1349],
        "IL11" => [41.1387, -88.6256],
        "IL18" => [40.2358, -89.7994],
        "IL15" => [39.4841, -88.3077],
        "IL17" => [40.1684, -90.0762],
        "IL19" => [38.7071, -89.171],
        "IL12" => [37.9923, -89.596],
        "IL10" => [42.1868, -87.9582],
        "IL09" => [42.0052, -87.7655],
        "IL05" => [41.9425, -87.7855],
        "IL04" => [41.8774, -87.7833],
        "IL01" => [41.6803, -87.7028],
        "IL02" => [41.5952, -87.655],
        "IN02" => [41.1258, -86.3732],
        "IN03" => [41.4561, -85.5573],
        "IN06" => [39.7442, -85.4698],
        "IN04" => [39.7707, -86.5608],
        "IN07" => [39.8158, -86.1697],
        "IN05" => [40.0582, -85.9671],
        "IN08" => [38.7786, -87.2957],
        "IN01" => [41.2714, -87.2532],
        "IN09" => [38.5689, -86.1382],
        "IA04" => [42.4512, -93.0664],
        "IA03" => [41.6066, -92.908],
        "IA05" => [42.0331, -95.7997],
        "IA01" => [42.3438, -91.0962],
        "IA02" => [41.099, -91.7316],
        "KS02" => [38.9749, -95.5598],
        "KS01" => [38.9483, -97.767],
        "KS04" => [37.5319, -96.7801],
        "KS03" => [38.9606, -94.999],
        "KY06" => [37.9789, -84.4634],
        "KY02" => [37.6125, -86.0599],
        "KY01" => [37.1931, -86.9524],
        "KY04" => [38.3903, -83.8622],
        "KY03" => [38.1816, -85.698],
        "KY05" => [37.6692, -83.208],
        "LA05" => [31.4385, -91.9905],
        "LA07" => [30.3491, -92.4529],
        "LA02" => [29.9615, -90.0425],
        "LA04" => [31.5773, -92.9559],
        "LA06" => [30.4521, -91.1419],
        "LA01" => [30.3534, -90.0471],
        "LA03" => [29.8318, -90.6079],
        "ME02" => [45.0836, -69.1146],
        "ME01" => [43.8979, -70.1176],
        "MD03" => [39.1706, -76.6363],
        "MD07" => [39.27, -76.8246],
        "MD06" => [39.5074, -77.7015],
        "MD02" => [39.3299, -76.481],
        "MD08" => [39.0751, -77.1573],
        "MD04" => [39.0437, -77.0318],
        "MD05" => [38.4876, -76.6805],
        "MD01" => [38.7071, -75.9875],
        "MA05" => [42.5643, -71.3531],
        "MA03" => [42.0481, -71.4383],
        "MA02" => [42.19, -72.258],
        "MA06" => [42.5781, -71.031],
        "MA01" => [42.3459, -72.3568],
        "MA07" => [42.3969, -71.1681],
        "MA08" => [42.3407, -71.078],
        "MA09" => [42.2153, -71.0924],
        "MA10" => [41.8091, -70.57],
        "MA04" => [42.005, -71.0867],
        "MI09" => [42.6219, -83.2693],
        "MI12" => [42.5128, -83.0518],
        "MI14" => [42.2496, -83.1728],
        "MI01" => [45.8269, -86.4973],
        "MI05" => [43.3089, -83.7273],
        "MI10" => [43.091, -82.9552],
        "MI02" => [43.7033, -85.8406],
        "MI03" => [42.9164, -85.3527],
        "MI04" => [44.0894, -84.992],
        "MI08" => [42.7532, -83.9321],
        "MI06" => [42.1641, -85.7968],
        "MI11" => [42.5014, -83.4697],
        "MI13" => [42.3402, -83.0632],
        "MI15" => [42.1319, -83.478],
        "MI07" => [42.287, -84.4599],
        "MN06" => [45.2471, -93.5135],
        "MN05" => [44.9767, -93.3108],
        "MN03" => [45.0328, -93.4684],
        "MN04" => [44.9662, -93.0783],
        "MN07" => [46.7268, -95.9848],
        "MN02" => [44.5539, -93.4046],
        "MN01" => [44.0666, -93.5085],
        "MN08" => [47.2512, -92.5904],
        "MS01" => [34.0446, -89.4178],
        "MS02" => [33.0328, -90.5084],
        "MS03" => [32.1131, -89.9979],
        "MS04" => [31.0472, -89.386],
        "MO04" => [38.3919, -93.2695],
        "MO09" => [39.0243, -91.7082],
        "MO05" => [38.9995, -94.401],
        "MO03" => [38.3439, -90.3948],
        "MO08" => [37.0262, -90.6568],
        "MO07" => [37.0598, -93.6217],
        "MO06" => [39.6291, -94.1156],
        "MO01" => [38.7083, -90.3509],
        "MO02" => [38.7479, -90.6033],
        "MTAL" => [46.53, -111.4122],
        "NE03" => [41.6493, -99.1875],
        "NE01" => [41.3207, -96.3584],
        "NE02" => [41.2637, -96.1026],
        "NV02" => [37.4104, -115.6442],
        "NV03" => [36.0906, -114.953],
        "NV01" => [36.1939, -115.1718],
        "NH01" => [43.3116, -71.2034],
        "NH02" => [43.9743, -71.761],
        "NJ05" => [40.9434, -74.653],
        "NJ11" => [40.8222, -74.5048],
        "NJ09" => [40.846, -74.0773],
        "NJ08" => [40.8479, -74.2282],
        "NJ13" => [40.7, -74.1425],
        "NJ10" => [40.7112, -74.2231],
        "NJ07" => [40.6116, -74.6062],
        "NJ12" => [40.3726, -74.4427],
        "NJ06" => [40.4213, -74.2602],
        "NJ04" => [40.1727, -74.4286],
        "NJ03" => [39.844, -74.6485],
        "NJ01" => [39.8444, -75.1242],
        "NJ02" => [39.5861, -74.9443],
        "NM03" => [35.2966, -106.5207],
        "NM01" => [34.9798, -106.5374],
        "NM02" => [34.2302, -106.6715],
        "NY28" => [43.1332, -78.1516],
        "NY26" => [42.9381, -78.0925],
        "NY25" => [43.1496, -76.5916],
        "NY20" => [42.7861, -74.0993],
        "NY21" => [42.7014, -74.0469],
        "NY24" => [42.7934, -75.638],
        "NY29" => [42.6497, -77.9115],
        "NY22" => [41.8235, -75.0774],
        "NY23" => [43.6158, -75.0143],
        "NY27" => [42.5839, -78.8695],
        "NY19" => [41.4269, -74.0981],
        "NY18" => [41.0773, -73.8625],
        "NY01" => [40.9452, -72.6666],
        "NY17" => [41.0018, -73.918],
        "NY15" => [40.8095, -73.9343],
        "NY16" => [40.8391, -73.8999],
        "NY02" => [40.7726, -73.3014],
        "NY05" => [40.7624, -73.7636],
        "NY14" => [40.7528, -73.9538],
        "NY07" => [40.7974, -73.8602],
        "NY08" => [40.6662, -73.9944],
        "NY09" => [40.6632, -73.8779],
        "NY04" => [40.6774, -73.6468],
        "NY10" => [40.6626, -73.9276],
        "NY11" => [40.6544, -73.96],
        "NY06" => [40.6731, -73.7789],
        "NY03" => [40.7232, -73.4801],
        "NY12" => [40.6969, -73.9576],
        "NY13" => [40.5957, -74.0503],
        "NC05" => [36.1192, -80.7314],
        "NC06" => [35.8094, -79.852],
        "NC04" => [35.8383, -78.8557],
        "NC12" => [35.7648, -80.3679],
        "NC10" => [35.7239, -81.7451],
        "NC11" => [35.5927, -82.6478],
        "NC13" => [36.0958, -79.2179],
        "NC03" => [35.4554, -77.2009],
        "NC09" => [35.2157, -80.8747],
        "NC02" => [35.5139, -78.4996],
        "NC01" => [35.6099, -77.4495],
        "NC08" => [35.0963, -79.736],
        "NC07" => [34.9068, -78.4913],
        "NDAL" => [47.4016, -98.2394],
        "OH17" => [41.1224, -81.2352],
        "OH16" => [40.8404, -81.7543],
        "OH05" => [41.0928, -83.5803],
        "OH06" => [39.643, -81.5316],
        "OH04" => [40.6563, -83.3676],
        "OH12" => [40.0825, -82.8942],
        "OH15" => [40.0022, -83.0666],
        "OH08" => [39.8031, -84.43],
        "OH03" => [39.5296, -84.0673],
        "OH07" => [39.7275, -83.1047],
        "OH18" => [39.8113, -82.1959],
        "OH02" => [39.0622, -83.9059],
        "OH01" => [39.255, -84.5595],
        "OH14" => [41.4172, -81.2144],
        "OH11" => [41.4702, -81.5986],
        "OH13" => [41.1964, -81.714],
        "OH10" => [41.4189, -81.6918],
        "OH09" => [41.4816, -82.827],
        "OK01" => [36.1804, -95.8235],
        "OK05" => [35.2779, -96.9331],
        "OK04" => [34.4678, -97.6009],
        "OK02" => [35.0538, -95.7379],
        "OK03" => [35.724, -98.1594],
        "OR01" => [45.5611, -123.1211],
        "OR05" => [45.0061, -122.7046],
        "OR04" => [43.7721, -122.7586],
        "OR03" => [45.3822, -122.29],
        "OR02" => [44.0407, -121.0112],
        "PA11" => [41.124, -75.7542],
        "PA17" => [40.4342, -76.5463],
        "PA04" => [40.6097, -80.0016],
        "PA07" => [39.9955, -75.4104],
        "PA19" => [40.0441, -76.996],
        "PA16" => [40.0957, -76.0687],
        "PA03" => [41.3075, -79.6576],
        "PA05" => [41.2323, -78.6838],
        "PA10" => [41.2916, -75.9711],
        "PA15" => [40.5357, -75.4481],
        "PA08" => [40.2598, -75.0704],
        "PA18" => [40.2667, -79.8503],
        "PA14" => [40.4279, -79.9237],
        "PA13" => [40.1511, -75.2052],
        "PA02" => [40.0117, -75.1642],
        "PA06" => [40.1744, -75.6231],
        "PA09" => [40.3702, -78.4565],
        "PA12" => [40.264, -79.5826],
        "PA01" => [39.9511, -75.2081],
        "RI02" => [41.6424, -71.5223],
        "RI01" => [41.7182, -71.3541],
        "SC04" => [34.8085, -82.1313],
        "SC03" => [34.347, -82.2557],
        "SC05" => [34.4159, -80.9145],
        "SC06" => [33.4764, -80.1607],
        "SC02" => [33.3005, -81.1068],
        "SC01" => [33.4031, -79.5838],
        "SDAL" => [43.8967, -98.1374],
        "TN05" => [36.2261, -86.7193],
        "TN01" => [36.0547, -83.0527],
        "TN07" => [35.8468, -87.6921],
        "TN08" => [35.8698, -88.8251],
        "TN04" => [35.8006, -86.0534],
        "TN06" => [35.9744, -86.3256],
        "TN02" => [35.7236, -84.1118],
        "TN09" => [35.1359, -89.9397],
        "TN03" => [35.8902, -84.193],
        "TX13" => [34.0502, -98.9984],
        "TX04" => [33.3602, -95.4733],
        "TX26" => [33.0689, -97.1491],
        "TX03" => [33.0385, -96.6726],
        "TX12" => [32.8116, -97.479],
        "TX32" => [32.8528, -96.8457],
        "TX19" => [33.2181, -100.5422],
        "TX30" => [32.7342, -96.7432],
        "TX24" => [32.8462, -96.9994],
        "TX01" => [31.9949, -94.7879],
        "TX17" => [31.0747, -96.4615],
        "TX05" => [32.2468, -95.814],
        "TX06" => [31.8517, -96.1596],
        "TX11" => [31.5089, -102.1026],
        "TX31" => [30.985, -97.2927],
        "TX08" => [30.4732, -94.7408],
        "TX21" => [29.9233, -98.3685],
        "TX25" => [30.0366, -97.4765],
        "TX10" => [30.1899, -96.6955],
        "TX02" => [29.9977, -94.8129],
        "TX07" => [29.8007, -95.5138],
        "TX18" => [29.8412, -95.3801],
        "TX29" => [29.799, -95.2363],
        "TX14" => [29.165, -95.8915],
        "TX09" => [29.6635, -95.4555],
        "TX28" => [28.1112, -98.5296],
        "TX23" => [30.4067, -101.8347],
        "TX22" => [29.5053, -95.4173],
        "TX20" => [29.4596, -98.4877],
        "TX16" => [31.7506, -106.3784],
        "TX27" => [27.1486, -97.5044],
        "TX15" => [27.6418, -97.5762],
        "UT03" => [39.935, -111.941],
        "UT02" => [39.8815, -111.3956],
        "UT01" => [40.577, -111.6971],
        "VTAL" => [44.0547, -72.457],
        "VA10" => [38.9696, -77.8704],
        "VA11" => [38.7662, -77.3612],
        "VA07" => [38.0769, -77.7645],
        "VA01" => [37.9084, -77.1531],
        "VA04" => [37.1548, -77.3865],
        "VA09" => [37.1741, -81.1542],
        "VA06" => [37.9764, -79.3038],
        "VA08" => [38.8667, -77.1898],
        "VA03" => [37.2428, -76.856],
        "VA02" => [37.2035, -76.0612],
        "VA05" => [37.411, -79.0925],
        "WA05" => [47.6671, -119.264],
        "WA08" => [47.1982, -121.7904],
        "WA09" => [47.1742, -122.4363],
        "WA02" => [48.2589, -121.7196],
        "WA01" => [47.7417, -122.3905],
        "WA07" => [47.5564, -122.3411],
        "WA06" => [47.5242, -123.1995],
        "WA04" => [47.3923, -120.57],
        "WA03" => [46.5243, -122.4582],
        "WV03" => [38.0112, -81.2898],
        "WV02" => [38.9035, -80.079],
        "WV01" => [39.3665, -80.2541],
        "WI07" => [46.094, -91.1843],
        "WI06" => [43.9128, -88.8065],
        "WI05" => [43.1022, -88.1925],
        "WI02" => [42.9638, -89.1944],
        "WI04" => [43.0418, -87.9773],
        "WI01" => [42.7763, -88.4674],
        "WI03" => [43.9192, -91.0355],
        "WI08" => [45.2353, -87.9871],
        "WYAL" => [42.9748, -107.5013],
        "PR98" => [18.2042, -66.318]
    }
    coords[district_name]
  end

end
