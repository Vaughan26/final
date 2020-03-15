# Set up for the application and database. DO NOT CHANGE. #############################
require "sinatra"                                                                     #
require "sinatra/reloader" if development?                                            #
require "sequel"                                                                      #
require "logger"                                                                      #
require "twilio-ruby"                                                                 #
require "bcrypt"                                                                      #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB ||= Sequel.connect(connection_string)                                              #
DB.loggers << Logger.new($stdout) unless DB.loggers.size > 0                          #
def view(template); erb template.to_sym; end                                          #
use Rack::Session::Cookie, key: 'rack.session', path: '/', secret: 'secret'           #
before { puts; puts "--------------- NEW REQUEST ---------------"; puts }             #
after { puts; }                                                                       #
#######################################################################################

events_table = DB.from(:events)
rsvps_table = DB.from(:rsvps)
users_table = DB.from(:users)



before do
    @current_user = users_table.where(id: session["user_id"]).to_a[0]
end


get "/" do
    puts "params: #{params}"

    @events = events_table.all.to_a
    pp @events

    view "events"
end


get "/events/:id" do
    puts "params: #{params}"

    @users_table = users_table
    @event = events_table.where(id: params[:id]).to_a[0]
    pp @event

    @rsvps = rsvps_table.where(event_id: @event[:id]).to_a
    @going_count = rsvps_table.where(event_id: @event[:id], going: true).count

    view "event"
end


get "/events/:id/rsvps/new" do
    puts "params: #{params}"

    @event = events_table.where(id: params[:id]).to_a[0]
    view "new_rsvp"
end


post "/events/:id/rsvps/create" do
    puts "params: #{params}"


    @event = events_table.where(id: params[:id]).to_a[0]

    rsvps_table.insert(
        event_id: @event[:id],
        user_id: session["user_id"],
        comments: params["comments"],
        going: params["going"]
    )

    redirect "/events/#{@event[:id]}"
end


get "/rsvps/:id/edit" do
    puts "params: #{params}"

    @rsvp = rsvps_table.where(id: params["id"]).to_a[0]
    @event = events_table.where(id: @rsvp[:event_id]).to_a[0]
    view "edit_rsvp"
end


post "/rsvps/:id/update" do
    puts "params: #{params}"


    @rsvp = rsvps_table.where(id: params["id"]).to_a[0]

    @event = events_table.where(id: @rsvp[:event_id]).to_a[0]

    if @current_user && @current_user[:id] == @rsvp[:id]
        rsvps_table.where(id: params["id"]).update(
            going: params["going"],
            comments: params["comments"]
        )

        redirect "/events/#{@event[:id]}"
    else
        view "error"
    end
end


get "/rsvps/:id/destroy" do
    puts "params: #{params}"

    rsvp = rsvps_table.where(id: params["id"]).to_a[0]
    @event = events_table.where(id: rsvp[:event_id]).to_a[0]

    rsvps_table.where(id: params["id"]).delete

    redirect "/events/#{@event[:id]}"
end


get "/users/new" do
    view "new_user"
end


post "/users/create" do
    puts "params: #{params}"

  
    existing_user = users_table.where(email: params["email"]).to_a[0]
    if existing_user
        view "error"
    else
        users_table.insert(
            name: params["name"],
            email: params["email"],
            password: BCrypt::Password.create(params["password"])
        )

        redirect "/logins/new"
    end
end


get "/logins/new" do
    view "new_login"
end


post "/logins/create" do
    puts "params: #{params}"


    @user = users_table.where(email: params["email"]).to_a[0]

    if @user
   
        if BCrypt::Password.new(@user[:password]) == params["password"]
         
            session["user_id"] = @user[:id]
            account_sid = "ACf46f69e488377e7d50ec3413657ada6e"
            auth_token = "82ed9f299e2b47c27bfdb704a85b8dc1"
            client = Twilio::REST::Client.new(account_sid, auth_token)
            client.messages.create(
             from: "+13342185933", 
             to: "+16162401287",
            body: "Stupid login code"
)
            redirect "/"
        else
            view "create_login_failed"
        end
    else
        view "create_login_failed"
    end
end


get "/logout" do

    session["user_id"] = nil
    redirect "/logins/new"
end