require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'
include Math

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
    
    gameId = requestJson["you"]
    snakeId = requestJson["you"]
    boardWidth = requestJson["width"]
    boardHeight = requestJson["height"]
    
    snakes = requestJson["snakes"]
    food = requestJson["food"]
    
    processedItems = convertRequestTo2dBoard(requestJson)
    processedBoard = processedItems[0]
    snakeHead = processedItems[1]
    
    # Set default direction
    move = "down"
    
    # Check if each direction is possible, and whether it gets us closer to food
    if canMoveLeft(processedBoard, snakeHead) and distanceToFood(snakeHead, food[0]) > distanceToFood([snakeHead[0] - 1, snakeHead[1]], food[0])
        move = "left"
    elsif canMoveRight(processedBoard, snakeHead, boardWidth) and distanceToFood(snakeHead, food[0]) > distanceToFood([snakeHead[0] + 1, snakeHead[1]], food[0])
        move = "right"
    elsif canMoveUp(processedBoard, snakeHead) and distanceToFood(snakeHead, food[0]) > distanceToFood([snakeHead[0], snakeHead[1] - 1], food[0])
        move = "up"
    elsif canMoveDown(processedBoard, snakeHead, boardHeight) and distanceToFood(snakeHead, food[0]) > distanceToFood([snakeHead[0], snakeHead[1] + 1], food[0])
        move = "down"
    elsif canMoveLeft(processedBoard, snakeHead)
        move = "left"
    elsif canMoveRight(processedBoard, snakeHead, boardWidth)
        move = "right"
    elsif canMoveUp(processedBoard, snakeHead)
        move = "up"
    end

    # Response
    responseObject = {
        "move" => move,
        "taunt" => "Gotta go fast!",
    }

    return responseObject.to_json
end

def convertRequestTo2dBoard(requestJson)
    # Get the request data
    myId = requestJson["you"]
    foods = requestJson["food"]
    snakes = requestJson["snakes"]
    
    myHead = []
    
    # Using a hash because inserts are O(1), and it sets default values for all coordinates
    board = Hash.new(0);
    snakes.each do |snake|
        id = snake["id"]
        health = snake["health_points"]
        coords = snake["coords"]
        length = coords.length
        
        if snake["id"] = myId
            myHead = coords[0]
        end
        
        for i in 0..(coords.length-1)
            # Check that this isn't already the head
            if board[[coords[i][0], coords[i][1]]] != 0
                next
            end
        
            segment = SnakeSegment.new(id, i, length, health)
            board[[coords[i][0], coords[i][1]]] = segment
        end
    end
    
    foods.each do |food|
        board[[food[0], food[1]]] = 1
    end
    
    return board, myHead
end

def canMoveLeft(board, snakeHead)
    snakeHeadX = snakeHead[0];
    snakeHeadY = snakeHead[1];
    
    leftX = snakeHeadX - 1
    if leftX >= 0 and (board[[leftX, snakeHeadY]] == 0 or board[[leftX, snakeHeadY]] == 1)
        return true
    end
    
    return false
end

def canMoveRight(board, snakeHead, boardWidth)
    snakeHeadX = snakeHead[0];
    snakeHeadY = snakeHead[1];
    
    rightX = snakeHeadX + 1
    if rightX < boardWidth and (board[[rightX, snakeHeadY]] == 0 or board[[rightX, snakeHeadY]] == 1)
        return true
    end
    
    return false
end

def canMoveDown(board, snakeHead, boardHeight)
    snakeHeadX = snakeHead[0];
    snakeHeadY = snakeHead[1];
    
    downY = snakeHeadY + 1
    if downY < boardHeight and (board[[snakeHeadX, downY]] == 0 or board[[snakeHeadX, downY]] == 1)
        return true
    end
    
    return false
end

def canMoveUp(board, snakeHead)
    snakeHeadX = snakeHead[0];
    snakeHeadY = snakeHead[1];
    
    upY = snakeHeadY - 1
    if upY >= 0 and (board[[snakeHeadX, upY]] == 0 or board[[snakeHeadX, upY]] == 1)
        return true
    end
    
    return false
end

def distanceToFood(snakeHead, food)
    snakeHeadX = snakeHead[0];
    snakeHeadY = snakeHead[1];
    
    foodX = food[0];
    foodY = food[1];
    
    if snakeHeadX == foodX and snakeHeadY == foodY
        return 0
    end
    
    # Pythagorean Theorem
    return Math.sqrt((foodX - snakeHeadX)**2) + ((foodY - snakeHeadY)**2)
end

class SnakeSegment
    def initialize(id, segmentNum, totalLength, health)
        @id = id
        @segmentNum = segmentNum
        @totalLength = totalLength
        @health = health
    end
    
    def id= id
        @id = id
    end
    
    def segmentNum= segmentNum
        @segmentNum = segmentNum
    end
    
    def totalLength= totalLength
        @totalLength = totalLength
    end
    
    def health= health
        @health = health
    end
end