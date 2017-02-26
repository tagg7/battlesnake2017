require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'
include Math

BLANK_VALUE = 0
FOOD_VALUE = 1

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
    
    # Extract data from the request object
    gameId = requestJson["game_id"]
    snakeId = requestJson["you"]
    boardWidth = requestJson["width"]
    boardHeight = requestJson["height"]
    snakes = requestJson["snakes"]
    foods = requestJson["food"]
    
    # Generate objects needed for future analysis
    board = generateBoard(snakes, foods)
    snakesLookup = generateSnakesLookup(snakes)
    snake = snakesLookup[snakeId]
    
    leftMoveScore = calculateScoreForSnakeMovement(board, snakesLookup, foods, snakeId, -1, 0, boardWidth, boardHeight)
    puts "Left Score = #{leftMoveScore}"
    rightMoveScore = calculateScoreForSnakeMovement(board, snakesLookup, foods, snakeId, 1, 0, boardWidth, boardHeight)
    puts "Right Score = #{rightMoveScore}"
    upMoveScore = calculateScoreForSnakeMovement(board, snakesLookup, foods, snakeId, 0, -1, boardWidth, boardHeight)
    puts "Up Score = #{upMoveScore}"
    downMoveScore = calculateScoreForSnakeMovement(board, snakesLookup, foods, snakeId, 0, 1, boardWidth, boardHeight)
    puts "Down Score = #{downMoveScore}"
    
    if leftMoveScore >= rightMoveScore and leftMoveScore >= upMoveScore and leftMoveScore >= downMoveScore
        move = "left"
    end
    if rightMoveScore >= leftMoveScore and rightMoveScore >= upMoveScore and rightMoveScore >= downMoveScore
        move = "right"
    end
    if upMoveScore >= leftMoveScore and upMoveScore >= rightMoveScore and upMoveScore >= downMoveScore
        move = "up"
    end
    if downMoveScore >= leftMoveScore and downMoveScore >= rightMoveScore and downMoveScore >= upMoveScore
        move = "down"
    end

    # Response
    responseObject = {
        "move" => move,
        "taunt" => "Gotta go fast!",
    }

    return responseObject.to_json
end

def calculateScoreForSnakeMovement(board, snakes, foods, snakeId, xOffset, yOffset, boardWidth, boardHeight)
    snake = snakes[snakeId]
    currentHeadCoord = snake.coords[0]
    
    # Verify that this position is not outside the board area
    if currentHeadCoord[0] + xOffset < 0 or currentHeadCoord[0] + xOffset >= boardWidth
        return -1
    end
    if currentHeadCoord[1] + yOffset < 0 or currentHeadCoord[1] + yOffset >= boardHeight
        return -1
    end
    
    # Verify that this position is not another snake's body
    currentObjectInPosition = board[[currentHeadCoord[0] + xOffset, currentHeadCoord[1] + yOffset]]
    if currentObjectInPosition.is_a?(SnakeSegment)
        matchingSnake = snakes[currentObjectInPosition.id]
        puts matchingSnake.coords[matchingSnake.coords.length-1]
        
        # If this position is currently a snake's tail, then we can safely access it because it will be moved further by next turn
        if matchingSnake.coords[matchingSnake.coords.length-1] != [currentHeadCoord[0] + xOffset, currentHeadCoord[1] + yOffset]
            return -1
        end
    end
    
    # Modify snake to new coordinates
    snakesClone = Marshal.load(Marshal.dump(snakes))
    snakeClone = Marshal.load(Marshal.dump(snake))
    
    for i in 1..(snakeClone.coords.length - 1)
        snakeClone.coords[i] = snakeClone.coords[i-1]
    end
    snakeClone.coords[0] = [currentHeadCoord[0] + xOffset, currentHeadCoord[1] + yOffset]
    snakesClone[snakeId] = snakeClone
    
    # # Modify board to move snake to given position
    # boardClone = board.clone
    
    # boardClone[[currentHeadCoord[0] + xOffset, currentHeadCoord[1] + yOffset]] = SnakeSegment.new(snakeId, 0, snake.totalLength, snake.health)
    # for i in 0..(snake.totalLength - 2)
    #     boardClone[snake.coords[i]].segmentNum += 1
    # end
    # if snake.coords[snake.totalLength-2] != snake.coords[snake.totalLength-1]
    #     boardClone[snake.coords[snake.totalLength-1]] = BLANK_VALUE
    # end
    
    # Calculate score for each source of food
    foodScore = 0
    for i in 0..(foods.length-1)
        foodScore += calculateScoreForSnakesProximityToFood(snakesClone, snakeId, foods[i])
    end
    
    # Weight the food score based on the snake's health
    foodScore *= 100 - snake.health
    
    # TODO: Verify that snake can get back to its own tail
    
    # TODO: Generate score based on the number of squares that the snake can access from this location
    
    return foodScore
end

def calculateScoreForSnakesProximityToFood(snakes, snakeId, food)
    snakeHead = snakes[snakeId].coords[0]
    
    distance = distanceToFood(snakeHead, food)
    puts "Distance to food = #{distance}"
    snakes.each do |otherSnakeId, otherSnake|
        if otherSnakeId == snakeId
            next
        end
        
        otherSnakeDistance = distanceToFood(otherSnake.coords[0], food)
        if otherSnakeDistance < distance
            return 0
        end
    end
    
    return 100 - distance
end

def generateBoard(snakes, foods)
    board = Hash.new(BLANK_VALUE);    # Using a hash because inserts are O(1), and it sets default values for all coordinates
    
    # Process each of the snakes
    snakes.each do |snake|
        id = snake["id"]
        health = snake["health_points"]
        coords = snake["coords"]
        length = coords.length
        
        for i in 0..(coords.length-1)
            # Check that this isn't already the head (when the snake starts, all body segments are on top of its head)
            if board[[coords[i][0], coords[i][1]]] != BLANK_VALUE
                next
            end
        
            segment = SnakeSegment.new(id, i, length, health)
            board[[coords[i][0], coords[i][1]]] = segment
        end
    end
    
    # Process all of the food locations
    foods.each do |food|
        board[[food[0], food[1]]] = FOOD_VALUE
    end
    
    return board
end

def generateSnakesLookup(snakes)
    snakesLookup = Hash.new
    
    # Process each of the snakes
    snakes.each do |snake|
        id = snake["id"]
        health = snake["health_points"]
        coords = snake["coords"]
        
        snakeLookup = Snake.new(coords.length, health, coords)
        snakesLookup[id] = snakeLookup
    end
    
    return snakesLookup
end

def canMoveLeft(board, snakeHead)
    snakeHeadX = snakeHead[0];
    snakeHeadY = snakeHead[1];
    
    leftX = snakeHeadX - 1
    if leftX >= 0 and (board[[leftX, snakeHeadY]] == BLANK_VALUE or board[[leftX, snakeHeadY]] == FOOD_VALUE)
        return true
    end
    
    return false
end

def canMoveRight(board, snakeHead, boardWidth)
    snakeHeadX = snakeHead[0];
    snakeHeadY = snakeHead[1];
    
    rightX = snakeHeadX + 1
    if rightX < boardWidth and (board[[rightX, snakeHeadY]] == BLANK_VALUE or board[[rightX, snakeHeadY]] == FOOD_VALUE)
        return true
    end
    
    return false
end

def canMoveDown(board, snakeHead, boardHeight)
    snakeHeadX = snakeHead[0];
    snakeHeadY = snakeHead[1];
    
    downY = snakeHeadY + 1
    if downY < boardHeight and (board[[snakeHeadX, downY]] == BLANK_VALUE or board[[snakeHeadX, downY]] == FOOD_VALUE)
        return true
    end
    
    return false
end

def canMoveUp(board, snakeHead)
    snakeHeadX = snakeHead[0];
    snakeHeadY = snakeHead[1];
    
    upY = snakeHeadY - 1
    if upY >= 0 and (board[[snakeHeadX, upY]] == BLANK_VALUE or board[[snakeHeadX, upY]] == FOOD_VALUE)
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
    
    return (foodX - snakeHeadX).abs + (foodY - snakeHeadY).abs
end

class SnakeSegment
    def initialize(id, segmentNum, totalLength, health)
        @id = id
        @segmentNum = segmentNum
        @totalLength = totalLength
        @health = health
    end
    
    attr_accessor :id
    attr_accessor :segmentNum
    attr_accessor :totalLength
    attr_accessor :health
end

class Snake
    def initialize(totalLength, health, coords)
        @totalLength = totalLength
        @health = health
        @coords = coords
    end
    
    attr_accessor :totalLength
    attr_accessor :health
    attr_accessor :coords
end