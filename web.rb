require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'
include Math

# http://battlesnake-773592db.b92493ea.svc.dockerapp.io:3201/

BLANK_VALUE = 0
FOOD_VALUE = 1
BREAD_CRUMB = 2

get '/' do
    return "Battlesnake: Hello World!"
end

post '/start' do
    requestBody = request.body.read
    requestJson = requestBody ? JSON.parse(requestBody) : {}
    
    responseObject = {
        "color" => "#D7B740",
        "secondary_color" => "#925818",
        "head_url" => "http://i.imgur.com/DdOHM2U.png",
        "head_type" => "fang",
        "tail_type" => "round-bum",
        "name" => "Double O Snake",
        "taunt" => "Her Majesty's Civil Serpent"
    }

    return responseObject.to_json
end

post '/move' do
    requestBody = request.body.read
    requestJson = requestBody ? JSON.parse(requestBody) : {}
    
    # Extract data from the request object
    #gameId = requestJson["game_id"]
    snakeId = requestJson["you"]
    boardWidth = requestJson["width"]
    boardHeight = requestJson["height"]
    snakes = requestJson["snakes"]
    foods = requestJson["food"]
    
    # Generate objects needed for future analysis
    board = generateBoard(snakes, foods)
    snakesLookup = generateSnakesLookup(snakes)
    snake = snakesLookup[snakeId]
    
    puts requestJson
    
    move = nil
    moveDecided = false
    
    # Routine 1: Go towards food
    moveForFood = determineClosestPieceOfFood(board, snakesLookup, snakeId, foods, boardWidth, boardHeight)
    if moveForFood != nil and (snake.health < 50 or moveForFood[0] < 10)
        if snakeCanGetBackToTail(board, snakesLookup, snakeId, moveForFood[1], boardWidth, boardHeight)
            moveDecided = true
            move = moveForFood[1]
        end
    end
    
    # Routine 2: Follow a snake
    if moveDecided == false and snakesLookup.length <= 3
        moveForSnakeToFollow = determineDirectionToFollowClosestSnake(board, snakesLookup, snakeId, boardWidth, boardHeight)
        if moveForSnakeToFollow != nil
            if snakeCanGetBackToTail(board, snakesLookup, snakeId, moveForSnakeToFollow, boardWidth, boardHeight)
                moveDecided = true
                move = moveForSnakeToFollow
            end
        end
    end
    
    # Routine 3: Select the direction with the shortest path to getting back to our tail
    if moveDecided == false and (snake.totalLength > 3 or snake.coords[snake.coords.length - 1] != snake.coords[snake.coords.length - 2])
        snakeHead = snake.coords[0]
        snakeTail = snake.coords[snake.coords.length - 1]
        
        shortestPathToTail = shortestPathBetweenTwoPoints(snakeHead[0], snakeHead[1], snakeTail[0], snakeTail[1], board, boardWidth, boardHeight)
        puts shortestPathToTail
        if shortestPathToTail != nil and shortestPathToTail[1] != nil
            moveDecided = true
            move = shortestPathToTail[1]
        end
    end
    
    # Routine 4: Randomly select a direction that does not immediately kill our snake
    if moveDecided == false
        randomValidMove = randomlySelectValidDirection(board, snakesLookup, snakeId, boardWidth, boardHeight)
        if randomValidMove != nil
            moveDecided = true
            move = randomValidMove
        end
    end
    
    # Routine Final: No safe direction; goodbye cruel world
    if moveDecided == false
        move = "down"
    end
    
    puts "I am moving #{move}"

    # Set the response
    responseObject = {
        "move" => move,
        "taunt" => "Her Majesty's Civil Serpent"
    }

    return responseObject.to_json
end

def determineDirectionToFollowClosestSnake(board, snakes, snakeId, boardWidth, boardHeight)
    snake = snakes[snakeId]
    snakeHead = snake.coords[0]
    
    shortestPath = -1
    shortestPathSnakeDirection = nil
    
    snakes.each do |otherSnakeId, otherSnake|
        if otherSnakeId == snakeId
            next
        end
        
        otherSnakeTail = otherSnake.coords[otherSnake.coords.length - 1]
        distance = shortestPathBetweenTwoPoints(snakeHead[0], snakeHead[1], otherSnakeTail[0], otherSnakeTail[1], board, boardWidth, boardHeight)
        
        if distance != nil
            if shortestPath == -1 or distance[0] < shortestPath
                shortestPath = distance[0]
                shortestPathSnakeDirection = distance[1]
            end
        end
    end
    
    return shortestPathSnakeDirection
end

def findDistanceToNearestSnakeOrWall(board, xPosition, yPosition, boardWidth, boardHeight)
    openList = Hash.new
    closedList = Hash.new
    
    startSquareCoords = [xPosition, yPosition]
    openList[startSquareCoords] = 0
    
    while !openList.empty?
        currentSquare = nil
        lowestFScore = -1
        openList.each do |key, value|
            if lowestFScore == -1 or value <= lowestFScore
                currentSquare = key
                lowestFScore = value
            end
        end
        
        closedList[currentSquare] = openList[currentSquare]
        openList.delete(currentSquare)
        
        adjacentSquaresCoords = [[currentSquare[0] - 1, currentSquare[1]], [currentSquare[0] + 1, currentSquare[1]], [currentSquare[0], currentSquare[1] - 1], [currentSquare[0], currentSquare[1] + 1]]
        adjacentSquaresCoords.each do |adjacentSquareCoords|
            # Verify this is a valid square
            if !snakeCanMoveToPosition(adjacentSquareCoords[0], adjacentSquareCoords[1], board, boardWidth, boardHeight)
                return closedList[currentSquare] + 1
            end
            
            if closedList.key?(adjacentSquareCoords)
                next
            end
            
            if !openList.key?(adjacentSquareCoords)
                openList[adjacentSquareCoords] = closedList[currentSquare] + 1
            end
        end
    end
    
    return nil
end

def determineClosestPieceOfFood(board, snakes, snakeId, foods, boardWidth, boardHeight)
    bestDirection = nil
    shortestDistance = -1
    
    snakeHead = snakes[snakeId].coords[0]
    
    for i in 0..(foods.length - 1)
        food = foods[i]
    
        # Calculate shortest path to the food
        shortestPathToFood = shortestPathBetweenTwoPoints(snakeHead[0], snakeHead[1], food[0], food[1], board, boardWidth, boardHeight)
        if shortestPathToFood == nil
            next
        end
        
        distance = shortestPathToFood[0]
        direction = shortestPathToFood[1]
        
        # Check that we haven't already found food that is closer than this
        if distance >= shortestDistance and shortestDistance != -1
            next
        end
        
        # Determine whether another snake is closer to the food than us
        otherSnakeCloser = false
        snakes.each do |otherSnakeId, otherSnake|
            if otherSnakeId != snakeId
                otherSnakeShortestPathToFood = shortestPathBetweenTwoPoints(otherSnake.coords[0][0], otherSnake.coords[0][1], food[0], food[1], board, boardWidth, boardHeight)
                if otherSnakeShortestPathToFood == nil
                    next
                end
                
                otherSnakeDistance = otherSnakeShortestPathToFood[0]
                if otherSnakeDistance < distance or (otherSnakeDistance == distance and otherSnake.totalLength >= snakes[snakeId].totalLength)
                    otherSnakeCloser = true
                    break
                end
            end
        end
        
        if otherSnakeCloser == true
            next
        end
        
        shortestDistance = distance
        bestDirection = direction
    end
    
    if bestDirection == nil
        return nil
    end
    
    return shortestDistance, bestDirection
end

# https://www.raywenderlich.com/4946/introduction-to-a-pathfinding
def shortestPathBetweenTwoPoints(startXPosition, startYPosition, endXPosition, endYPosition, board, boardWidth, boardHeight)
    if startXPosition ==  endXPosition and startYPosition == endYPosition
        return 0, nil
    end
    
    openList = Hash.new
    closedList = Hash.new
    
    endSquareCoords = [endXPosition, endYPosition]
    startSquareCoords = [startXPosition, startYPosition]
    optimalDistanceToEnd = distanceToCoord(startXPosition, startYPosition, endXPosition, endYPosition)
    
    startSquare = PathfinderSegment.new(startSquareCoords, nil, 0, optimalDistanceToEnd, optimalDistanceToEnd)
    openList[startSquareCoords] = startSquare
    
    while !openList.empty?
        # Get the square with the lowest F score
        currentSquare = nil
        lowestFScore = -1
        openList.each do |key, segment|
            if lowestFScore == -1 or segment.fValue <= lowestFScore
                currentSquare = segment
                lowestFScore = segment.fValue
            end
        end
        
        closedList[currentSquare.coords] = currentSquare
        openList.delete(currentSquare.coords)
        
        # We have found a path
        if closedList.key?(endSquareCoords)
            length = 0
            currentSquare = closedList[endSquareCoords]
            previousSquare = nil
            
            if currentSquare.parent == nil
                previousSquare = startSquare
                length = 1
            end
            
            while currentSquare.parent != nil
                previousSquare = currentSquare
                currentSquare = closedList[currentSquare.parent]
                length += 1
            end
            
            if currentSquare.coords[0] < previousSquare.coords[0]
                direction = "right"
            elsif currentSquare.coords[0] > previousSquare.coords[0]
                direction = "left"
            elsif currentSquare.coords[1] > previousSquare.coords[1]
                direction = "up"
            elsif currentSquare.coords[1] < previousSquare.coords[1]
                direction = "down"
            end
            
            return length, direction
        end
        
        adjacentSquaresCoords = [[currentSquare.coords[0] - 1, currentSquare.coords[1]], [currentSquare.coords[0] + 1, currentSquare.coords[1]], [currentSquare.coords[0], currentSquare.coords[1] - 1], [currentSquare.coords[0], currentSquare.coords[1] + 1]]
        adjacentSquaresCoords.each do |adjacentSquareCoords|
            # Verify this is a valid square
            if (!snakeCanMoveToPosition(adjacentSquareCoords[0], adjacentSquareCoords[1], board, boardWidth, boardHeight) and 
                endSquareCoords != [adjacentSquareCoords[0], adjacentSquareCoords[1]])
                next
            end
            
            if closedList.key?(adjacentSquareCoords)
                next
            end
            
            if !openList.key?(adjacentSquareCoords)
                adjacentSquareDistanceToEnd = distanceToCoord(adjacentSquareCoords[0], adjacentSquareCoords[1], endXPosition, endYPosition)
                openList[adjacentSquareCoords] = PathfinderSegment.new(adjacentSquareCoords, currentSquare.coords, currentSquare.gValue + 1, adjacentSquareDistanceToEnd, currentSquare.gValue + 1 + adjacentSquareDistanceToEnd)
            else
                if currentSquare.gValue + 1 < openList[adjacentSquareCoords].gValue
                    openList[adjacentSquareCoords].gValue = currentSquare.gValue + 1
                    openList[adjacentSquareCoords].fValue = openList[adjacentSquareCoords].gValue + openList[adjacentSquareCoords].hValue
                end
            end
        end
    end
    
    return nil
end

def snakeCanGetBackToTail(board, snakes, snakeId, direction, boardWidth, boardHeight)
    snake = snakes[snakeId]
    snakeHead = snake.coords[0]
    snakeTail = snake.coords[snake.coords.length - 1]
    
    shortestPath = nil
    if direction == "left"
        shortestPath = shortestPathBetweenTwoPoints(snakeHead[0] - 1, snakeHead[1], snakeTail[0], snakeTail[1], board, boardWidth, boardHeight)
    elsif direction == "right"
        shortestPath = shortestPathBetweenTwoPoints(snakeHead[0] + 1, snakeHead[1], snakeTail[0], snakeTail[1], board, boardWidth, boardHeight)
    elsif direction == "up"
        shortestPath = shortestPathBetweenTwoPoints(snakeHead[0], snakeHead[1] - 1, snakeTail[0], snakeTail[1], board, boardWidth, boardHeight)
    elsif direction == "down"
        shortestPath = shortestPathBetweenTwoPoints(snakeHead[0], snakeHead[1] + 1, snakeTail[0], snakeTail[1], board, boardWidth, boardHeight)
    end
    
    if shortestPath != nil
        return true
    end
    
    return false
end

def randomlySelectValidDirection(board, snakes, snakeId, boardWidth, boardHeight)
    snake = snakes[snakeId]
    snakeHead = snake.coords[0]
    
    if snakeCanMoveToPosition(snakeHead[0] - 1, snakeHead[1], board, boardWidth, boardHeight)
        return "left"
    elsif snakeCanMoveToPosition(snakeHead[0] + 1, snakeHead[1], board, boardWidth, boardHeight)
        return "right"
    elsif snakeCanMoveToPosition(snakeHead[0], snakeHead[1] - 1, board, boardWidth, boardHeight)
        return "up"
    elsif snakeCanMoveToPosition(snakeHead[0], snakeHead[1] + 1, board, boardWidth, boardHeight)
        return "down"
    end
    
    return nil
end

=begin
This method returns true if the specified position is empty (and inside the board). If the space is currently occupied by a snake's tail, then it will also return true.
For all other scenarios, returns false.
=end
def snakeCanMoveToPosition(xPosition, yPosition, board, boardWidth, boardHeight)
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
        return currentObjectInPosition.isTailThatWillMoveNextTurn
    end
    
    return true
end

=begin
This method returns the exact distance to the selected space in squares.
=end
def distanceToCoord(startXPosition, startYPosition, endXPosition, endYPosition)
    if startXPosition == endXPosition and startYPosition == endYPosition
        return 0
    end
    
    return (startXPosition - endXPosition).abs + (startYPosition - endYPosition).abs
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
            
            # Add the tail attribute if valid
            isTailThatWillMoveNextTurn = false
            if i == coords.length-1 and coords[i] != coords[i-1]
                isTailThatWillMoveNextTurn = true
            end
        
            segment = SnakeSegment.new(id, i, length, health, isTailThatWillMoveNextTurn)
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
    def initialize(id, segmentNum, totalLength, health, isTailThatWillMoveNextTurn)
        @id = id
        @segmentNum = segmentNum
        @totalLength = totalLength
        @health = health
        @isTailThatWillMoveNextTurn = isTailThatWillMoveNextTurn
    end
    
    attr_accessor :id
    attr_accessor :segmentNum
    attr_accessor :totalLength
    attr_accessor :health
    attr_accessor :isTailThatWillMoveNextTurn
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

class PathfinderSegment
    def initialize(coords, parent, gValue, hValue, fValue)
        @coords = coords
        @parent = parent
        @gValue = gValue
        @hValue = hValue
        @fValue = fValue
    end
    
    attr_accessor :coords
    attr_accessor :parent
    attr_accessor :gValue
    attr_accessor :hValue
    attr_accessor :fValue
end