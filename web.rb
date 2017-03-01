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
    
    # Select the move with the highest score
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

    # Set the response
    responseObject = {
        "move" => move,
        "taunt" => "Gotta go fast!",
    }

    return responseObject.to_json
end

=begin
This method calculates a score that should be used to determine which direction to move the snake for the given x- and y-offset.
A score of -1 means that the direction is a wall or snake.
=end
def calculateScoreForSnakeMovement(board, snakes, foods, snakeId, xOffset, yOffset, boardWidth, boardHeight)
    snake = snakes[snakeId]
    snakeHead = snake.coords[0]
    
    xPosition = snakeHead[0] + xOffset
    yPosition = snakeHead[1] + yOffset
    
    # Verify that the square does not contain another snake or is a wall
    validMove = snakeCanMoveToPosition(xPosition, yPosition, board, snakes, boardWidth, boardHeight)
    if validMove == false
        return -1
    end
    
    # Modify the snakes lookup to simulate the snake moving to the specified position
    snakesClone = moveSnakeInSnakesLookup(snakes, snakeId, xPosition, yPosition)
    #boardClone = moveSnakeInBoard(board, snakeId, xPosition, yPosition)
    
    # Calculate score for each source of food
    foodScore = 0
    for i in 0..(foods.length - 1)
        foodScore += calculateScoreForSnakesProximityToFood(snakesClone, snakeId, foods[i])
    end
    
    # Weight the food score based on the snake's remaining health
    foodScore *= 100 - snake.health
    
    # TODO: Verify that snake can get back to its own tail
    
    # TODO: Generate score based on the number of squares that the snake can access from this location
    
    totalScore = foodScore
    
    return totalScore
end

=begin
This method returns true if the specified position is empty (and inside the board). If the space is currently occupied by a snake's tail, then it will also return true.
For all other scenarios, returns false.
=end
def snakeCanMoveToPosition(xPosition, yPosition, board, snakes, boardWidth, boardHeight)
    # Verify that this position is not outside the board area
    if xPosition < 0 or xPosition >= boardWidth
        return false
    end
    if yPosition < 0 or yPosition >= boardHeight
        return false
    end
    
    # Verify that this position is not another snake's body
    currentObjectInPosition = board[[xPosition, yPosition]]
    if currentObjectInPosition.is_a?(SnakeSegment)
        matchingSnake = snakes[currentObjectInPosition.id]
        
        # If this position is currently a snake's tail, then we can safely access it because it will be moved further by next turn
        # NOTE: Edge case when starting out - body is collapsed onto multiple squares
        if (matchingSnake.coords[matchingSnake.coords.length-1] == [xPosition, yPosition]) and (matchingSnake.coords[matchingSnake.coords.length-1] != matchingSnake.coords[matchingSnake.coords.length-2])
            return true
        end
        
        return false
    end
    
    return true
end

=begin
This method returns a score out of 100 based on how close the food is. If another snake is closer to the food than the selected snake, then the score is 0.
=end
def calculateScoreForSnakesProximityToFood(snakes, snakeId, food)
    snakeHead = snakes[snakeId].coords[0]
    
    # Calculate our distance to the food
    distance = distanceToFood(snakeHead, food)
    
    # Determine whether another snake is closer to the food than us
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

=begin
This method returns the exact distance to the selected food in squares.
=end
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

=begin
This method generates a two dimensional board.
Each square with a snake in it contains a SnakeSegment object (containing the snake ID, segment number, length and health of the snake it is a part of).
Each square with food in it contains a food value (1).
Each blank square contains a blank value (0).
Note that the hash table is not bound by the height and width, so that must be calculated separately.
=end
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

=begin
This method generates a lookup dictionary for snakes, with the key being the snake ID and the value containing information about the snake.
=end
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

=begin
Returns a cloned snakes lookup object, with the selected snake moved to the given coordinates
=end
def moveSnakeInSnakesLookup(snakes, snakeId, headXPosition, headYPosition)
    snake = snakes[snakeId]
    
    # Perform a deep clone
    snakesClone = Marshal.load(Marshal.dump(snakes))
    snakeClone = Marshal.load(Marshal.dump(snake))
    
    for i in 1..(snakeClone.coords.length - 1)
        snakeClone.coords[i] = snakeClone.coords[i-1]
    end
    snakeClone.coords[0] = [headXPosition, headYPosition]
    snakesClone[snakeId] = snakeClone
    
    return snakesClone
end

=begin
Returns a clone board object, with the selected snake moved to the given coordinates
=end
def moveSnakeInBoard(board, snakeId, headXPosition, headYPosition)
    snake = snakes[snakeId]
    
    # Perform a deep clone
    boardClone = Marshal.load(Marshal.dump(board))
    
    boardClone[[headXPosition, headYPosition]] = SnakeSegment.new(snakeId, 0, snake.totalLength, snake.health)
    for i in 0..(snake.totalLength - 2)
        boardClone[snake.coords[i]].segmentNum += 1
    end
    if snake.coords[snake.totalLength - 2] != snake.coords[snake.totalLength - 1]
        boardClone[snake.coords[snake.totalLength-1]] = BLANK_VALUE
    end
    
    return boardClone
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