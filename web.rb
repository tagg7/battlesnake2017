require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'

get '/' do
    return "Battlesnake: Hello World!"
end

post '/start' do
    requestBody = request.body.read
    requestJson = requestBody ? JSON.parse(requestBody) : {}

    # TODO: Get ready to start a game with the request data
    
    responseObject = {
        "color" => "#87CEEB",
        "head_url" => "http://i.imgur.com/0LyUPYl.png",
        "name" => "Test Snake",
        "taunt" => "Her Majesty's Civil Serpent",
    }

    return responseObject.to_json
end

post '/move' do
    requestBody = request.body.read
    requestJson = requestBody ? JSON.parse(requestBody) : {}
    
    # Set default direction
    move = "down"

    # Get the request data
    gameId = requestJson["you"]
    snakeId = requestJson["you"]
    boardWidth = requestJson["width"]
    boardHeight = requestJson["height"]
    food = requestJson["food"]
    snakes = requestJson["snakes"]
    
    firstFoodX = food[0][0]
    firstFoodY = food[0][1]
    
    # Iterate through each of the snakes
    snakes.each do |snake|
        if snake["id"] = snakeId
            coords = snake["coords"]
            
            headX = coords[0][0]
            headY = coords[0][1]
            
            nextSegmentX = coords[1][0]
            nextSegmentY = coords[1][1]
            
            # Move to the same x-position as the food
            if firstFoodX < headX and nextSegmentX != headX - 1
                move = "left"
            elsif firstFoodX > headX and nextSegmentX != headX + 1
                move = "right"
            else
                # Move to the same y-position as the food
                if firstFoodY < headY and nextSegmentY != headY - 1
                    move = "up"
                elsif firstFoodY > headY and nextSegmentY != headY + 1
                    move = "down"
                end
            end
        end
    end

    # Response
    responseObject = {
        "move" => move,
        "taunt" => "Gotta go fast!",
    }

    return responseObject.to_json
end