#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <stdlib.h>
#include "pgmIO.h"
#include "i2c.h"
#include "definitions.xc"
void calcLeftBitsFull(unsigned char currentByte, unsigned char aboveCurrentByte, unsigned char belowCurrentByte, unsigned char adjacentByte, unsigned char aboveAdjacentByte, unsigned char belowAdjacentByte, unsigned char* currentValue, unsigned int* aliveCells);
unsigned char cellAlive (unsigned char neighbours, unsigned char cellAlive);
void calcRightMostBitFull(unsigned char currentByte, unsigned char aboveCurrentByte, unsigned char belowCurrentByte, unsigned char adjacentByte, unsigned char aboveAdjacentByte, unsigned char belowAdjacentByte, unsigned char* currentValue, unsigned int* aliveCells);
/////////Worker skip skips bytes that will remain empty at start and end of each row it is responsible for//////////
////////Below are the functions that are combined in workerJoint and workerShipMerged for optimisation reasons////////
//////// Transmission functions remain merged here due to memory restrictions ////////////////////////////
////////Buffer functions remain merged here due to memory and performance restrictions//////////



//returns if cell is alive given its number of neighbours.
inline unsigned char cellAlive (unsigned char neighbours, unsigned char cellAlive)
{
    if (neighbours >3){return 0;}
    else if (cellAlive)
    {
        if (neighbours < 2) {return 0;}
        else return 1;
    }
    else
    {
        if (neighbours < 3) {return 0;}
        else return 1;
    }

}

//Takes a byte, and its vertical and left hand neighbours, and calculates all but the rightmost bit for that byte
//Takes a pointer to a byte and uses that as its output.
//Takes a pointer to an int and increments it for each live cell it encounters.
inline void calcLeftBitsFull(unsigned char currentByte, unsigned char aboveCurrentByte, unsigned char belowCurrentByte, unsigned char adjacentByte, unsigned char aboveAdjacentByte, unsigned char belowAdjacentByte, unsigned char* currentValue, unsigned int* aliveCells)
{
    unsigned char cellIsAlive = 0;
    unsigned char neighbours = 0;
    unsigned int livingCells = 0;
    unsigned char tempByte = 0;
    neighbours += (currentByte &64) >> 6;
    neighbours += (aboveCurrentByte &64)  >> 6;
    neighbours += (belowCurrentByte &64)  >> 6;

    neighbours += (aboveCurrentByte &128) >> 7;
    neighbours += (belowCurrentByte &128) >> 7;

    neighbours += adjacentByte &1;
    neighbours += aboveAdjacentByte &1;
    neighbours += belowAdjacentByte &1;

    cellIsAlive = cellAlive(neighbours, currentByte &128);
    tempByte = cellIsAlive;
    livingCells+= cellIsAlive;



    if (currentByte + aboveCurrentByte + belowCurrentByte >2)
    {
        for (int byteIndex = 1; byteIndex < 7; byteIndex ++)
        {
            neighbours = (currentByte & 128)>>7;
            neighbours += (currentByte & 32)>>5;

            if(belowCurrentByte != 0)
            {
                neighbours += (belowCurrentByte &128)>>7;
                neighbours += (belowCurrentByte &64)>>6;
                neighbours += (belowCurrentByte &32)>>5;
            }
            if(aboveCurrentByte != 0)
            {
                neighbours += (aboveCurrentByte &128)>>7;
                neighbours += (aboveCurrentByte &64)>>6;
                neighbours += (aboveCurrentByte &32)>>5;
            }

            cellIsAlive = cellAlive(neighbours, currentByte & 64);
            tempByte = (tempByte<<1)|cellIsAlive;
            livingCells += cellIsAlive;

            currentByte = currentByte<<1;
            aboveCurrentByte = aboveCurrentByte<<1;
            belowCurrentByte = belowCurrentByte<<1;
        }
        *aliveCells += livingCells;
        *currentValue = (*currentValue << 6)|tempByte;
    }
    else
    {
        *currentValue = (tempByte)<<6;
    }
}
//Takes a byte, and its vertical and left hand neighbours, and calculates the rightmost bit for that byte
//Takes a pointer to a byte and appens its output to it.
//Takes a pointer to an int and increments it if rightmost cell is live.
inline void calcRightMostBitFull(unsigned char currentByte, unsigned char aboveCurrentByte, unsigned char belowCurrentByte, unsigned char adjacentByte, unsigned char aboveAdjacentByte, unsigned char belowAdjacentByte, unsigned char* currentValue, unsigned int* aliveCells)
{
    unsigned char cellIsAlive = 0;
    unsigned char neighbours = 0;
    neighbours += (currentByte &2)>>1;
    neighbours += (aboveCurrentByte &2)>>1;
    neighbours += (belowCurrentByte &2) >>1;

    neighbours += aboveCurrentByte &1;
    neighbours += belowCurrentByte &1;

    neighbours += (adjacentByte &128)>>7;
    neighbours += (aboveAdjacentByte &128)>>7;
    neighbours += (belowAdjacentByte &128)>>7;

    cellIsAlive = cellAlive(neighbours, currentByte &1);
    *currentValue = ((*currentValue) << 1)|cellIsAlive ;
    *aliveCells += cellIsAlive;
}


//Loads initial values from distributor into lifeGrid.
//Uses redundent bits at right and left of grid to store 7bit numbers,
//Left 7bit number represents position of 1st non zero byte per row
//Right 7bit number represents offset from last array position of last non zero byte per row
void loadArray(lifeGrid , chanend distributor)
{
    char input = 0;
    char needVal = 1;
    int lastVal = byteWidthPerWorker +1;
    for (int j = 0; j<bitHeightPerWorker; j++)//For each row
    {
        grid [0][j+1] = 0;//Set the left edge to equal 0.
        grid [byteWidthPerWorker+1][j+1] = 0;//Set the right edge to equal 0.
        needVal = 1;
        for (int i = 0; i<(byteWidthPerWorker); i++)// for each byte
        {

            distributor :> input;
            if (input)//If its on, store start and update end positions respectively
            {
                if (needVal)
                {
                    needVal = 0;
                    if (126 < i){grid [0][j+1] = 254;}//Yes I know this looks wrong but i+1
                    else {grid [0][j+1] = ((i+1)<<1);}

                }
                lastVal = i+1;
            }

            grid [i+1] [j+1] = input;//store byte

        }
        lastVal = ((byteWidthPerWorker+1)-lastVal);
        if (lastVal > 127) {lastVal = 127;}
        grid [byteWidthPerWorker+1] [j+1] = lastVal;//store end position
    }
}

//Passes and receives needed edge data with its neighbouring workers. Updates lifegrid for start and end values.
void transferData(lifeGrid, chanend up, chanend down, chanend left, chanend right, char parity)
{
    char input = 0;
    char startUpper= 0;
    char startLower = 0;
    int endUpper = 0;
    int endLower = 0;
    for(char t = 0; t < 2; t++)//LEFT AND RIGHT BORDERS
    {
        if(parity == t)
        {
            for(int i = 0; i < bitHeightPerWorker; i++)
            {
                left :> input;
                if (input &1) {grid [0] [i + 1]= 3;}//If left byte is on, set start to 1, and indicate bit is on. 11 = 3
                else {grid [0] [i+1] = grid [0] [i+1] &254;} //else ensure bit indicating cell is off. Maintain other bits

                right :> input;
                if (input &128) {grid [byteWidthPerWorker + 1] [i + 1]= 128;}//If right  byte is on, set end to 0, and indicate bit is on. 1000000 = 128
                else {grid [byteWidthPerWorker + 1] [i + 1] = grid [byteWidthPerWorker + 1] [i + 1] &127;}//else ensure bit is off. Maintain other bits.

            }
        }
        else
        {
            for(int i = 0; i < bitHeightPerWorker; i++)
            {
                right <: grid [byteWidthPerWorker] [i + 1];//Transmit edge information.
                left <: grid [1] [i + 1];
            }
        }
    }


    for(char t = 0; t < 2; t++)//TOP AND BOTTOM BORDERS
    {
        if(parity == t)
        {
            for(int i = 0; i < byteWidthPerWorker; i++)//Reads top and bottom row, maintains start and end metrics for corner cells.
            {
                up :> input;
                if (input)
                {
                    if (!startUpper)
                    {
                        if (i>126){startUpper = 126;}
                        else {startUpper = i+1;}
                    }
                    endUpper = i+1;
                }
                grid [i + 1] [0] = input;

                down :> input;
                if (input)
                {
                    if (!startLower)
                    {
                        if (i>126){startLower = 126;}
                        else {startLower = i+1;}
                    }
                    endLower = i+1;
                }
                grid [i + 1] [bitHeightPerWorker + 1] = input;
            }
        }
        else//Transmit top and bottom rows.
        {
            for(int i = 0; i < byteWidthPerWorker; i++)
            {
                down <: grid [i + 1] [bitHeightPerWorker];
                up <: grid [i + 1] [1];
            }
        }
    }
    endUpper = ((byteWidthPerWorker + 1)-endUpper);
    if (endUpper > 127) {endUpper = 127;}//if metrics are outside of bounds, correct them
    endLower = ((byteWidthPerWorker + 1)-endLower);
    if (endLower > 127) {endLower = 127;}

    for(char t = 0; t < 2; t++)
    {
        if(parity == t)//Receive input from corners, and input previous start end metrics appropriately.
        {
            left :> input;
            if (input&1) {grid [0] [0] = 3;}
            else {grid [0] [0] = (startUpper<<1);}
            left :> input;
            if (input &1) {grid [0] [bitHeightPerWorker+1] = 3;}
            else {grid [0] [bitHeightPerWorker+1] = startLower<<1;}

            right :> input;
            if (input &128) {grid [(byteWidthPerWorker)+1] [0] =128;}
            else
            {
                grid [(byteWidthPerWorker)+1] [0] = endUpper;

            }

            right :> input;
            if (input &128) {grid [(byteWidthPerWorker)+1] [bitHeightPerWorker+1] = 128;}
            else {grid [(byteWidthPerWorker)+1] [bitHeightPerWorker+1] = endLower;}
        }
        else//Transmit corner values received from top and bottom neighbours, to left and right neighbours.
        {
            right <: grid [(byteWidthPerWorker)] [0];
            right <: grid [(byteWidthPerWorker)] [bitHeightPerWorker+1];

            left <: grid [1] [0];
            left <: grid [1] [bitHeightPerWorker+1];
        }
    }

}


//Calculates another iteration of the lifeGrid
//returns number of live cells
//Maintains internal Queue within buffer
unsigned int calcGrid(lifeGrid )
{
    unsigned int aliveCells = 0;
    unsigned int* ap = &aliveCells;

    //Queue Values
    unsigned char buffer [bufferLength];
    unsigned int bufferHead = 0;
    unsigned int bufferTail = 0;
    unsigned int gridInsertX = 1;
    unsigned int gridInsertY = 1;
    int fullTailPosition;

    //Byte stores
    unsigned char adjacentDataInA = 0;
    unsigned char byteA;
    unsigned char aboveByteA;
    unsigned char belowByteA;
    unsigned char byteB;
    unsigned char aboveByteB;
    unsigned char belowByteB;
    unsigned char newData = 0;
    unsigned char* byteStore = &newData;


    //Values to handle skipping.
    char prevStart = grid[0][0];
    int prevEnd = grid[0][byteWidthPerWorker+1];
    char start = 1;
    unsigned int end = byteWidthPerWorker+1;
    char startNeeded;
    char nextStart;
    int nextEnd;

    for (int y = 1; y < bitHeightPerWorker + 1; y++)//For each row
    {

        adjacentDataInA = 0;//Reset values
        startNeeded = 1;
        nextStart = 254;
        nextEnd = 0;

        start = (grid [0] [y-1])>>1;//Find the earliest cell in the adjacent rows, set start to 1 before it
        newData = grid [0][y]>>1;
        if (start > newData){start = newData;}
        newData = grid [0][y+1]>>1;
        if (start > newData){start = newData;}
        if (start > byteWidthPerWorker+1) { start = byteWidthPerWorker+1;}
        if (start < 2) {start = 1;}//Handle edge cases where start value is 1st or second cell.
        else {start--;}

        end =  grid [byteWidthPerWorker+1] [y-1] & 127;//Find latest cell in adjacent rows and set end to it, plus 2 to exit its
        newData = grid [byteWidthPerWorker+1] [y] &127;//Sphere of influence.
        if (end > newData){end = newData;}
        newData = grid [byteWidthPerWorker+1] [y+1] & 127;
        if (end > newData){end = newData;}
        end = ((byteWidthPerWorker+1) -end)+2;
        if (end > byteWidthPerWorker){end = byteWidthPerWorker+1;}
        if (start > end) {end = start;}

        for (int x = 1; x < start; x++)//Until we reach index of 1st non zero cell push 0's into Queue;
        {

            fullTailPosition = bufferHead -1;
            if (fullTailPosition < 0) { fullTailPosition = bufferLength-1;}
            if (bufferTail == fullTailPosition)
            {
                grid[gridInsertX][gridInsertY] =  buffer[bufferHead]; // If Queue is full output into lifegrid
                bufferHead++;                                          //Queue is long enough to ensure none of the output cells
                if (bufferHead == bufferLength){bufferHead = 0;}        // will be used again.

                gridInsertX++;
                if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
            }
            buffer[bufferTail] = 0;
            bufferTail ++;
            if (bufferTail == bufferLength) {bufferTail = 0;}

        }
        if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
        // start = 1;

        byteA = grid [start] [y];//Set bytes stores to equal start byte, and its lefthand and vertical neighbours
        aboveByteA = grid [start] [y-1];
        belowByteA = grid [start] [y+1];

        byteB = grid [start-1] [y];
        aboveByteB = grid [start-1] [y-1];
        belowByteB = grid [start-1] [y+1];
        for (int x = start; x < end; x++)//For all bytes between start and end byte positions.
        {

            newData = 0;

            if(adjacentDataInA)//If A contains left hand adjacent data
            {
                calcLeftBitsFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);
                //calculate leftHand data.
                byteA = grid [x+1] [y];//Set A to equal right hand side neighbours of currentByte
                aboveByteA = grid [x+1] [y-1];
                belowByteA = grid [x+1] [y+1];
                //calculate righthand data
                calcRightMostBitFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);

            }
            else//If B contains left hand adjacent data
            {
                calcLeftBitsFull(byteA, aboveByteA, belowByteA, byteB, aboveByteB, belowByteB, byteStore, ap);
                //calculate leftHand data.

                byteB = grid [x+1] [y];//Set B to equal right hand side neighbours of currentByte
                aboveByteB = grid [x+1] [y-1];
                belowByteB = grid [x+1] [y+1];
                //calculate righthand data
                calcRightMostBitFull(byteA, aboveByteA, belowByteA, byteB, aboveByteB, belowByteB, byteStore, ap);

            }
            if (newData)// if byte is non zero update start end metrics for it.
            {
                if (startNeeded)
                {
                    startNeeded = 0;
                    if (x > 127) {nextStart = 254;}
                    else {nextStart = x <<1;}

                }
                nextEnd = x;
            }
            adjacentDataInA = !adjacentDataInA;// after this iteration the right hand cell becomes active, active becomes left hand

            fullTailPosition = bufferHead -1;//Push item onto queue, popping if needed.
            if (fullTailPosition < 0) { fullTailPosition = bufferLength-1;}
            if (bufferTail == fullTailPosition)
            {

                grid[gridInsertX][gridInsertY] = (unsigned char) buffer[bufferHead];//If queue is full output into grid
                bufferHead++;
                if (bufferHead == bufferLength){bufferHead = 0;}

                gridInsertX++;
                if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
            }
            buffer[bufferTail] = newData;
            bufferTail ++;
            if (bufferTail == bufferLength) {bufferTail = 0;}

        }
        for (int x = end; x < byteWidthPerWorker+1; x++)//Fill buffer with 0's for all bytes past end position
        {
            fullTailPosition = bufferHead -1;
            if (fullTailPosition < 0) { fullTailPosition = bufferLength-1;}
            if (bufferTail == fullTailPosition)
            {

                grid[gridInsertX][gridInsertY] = (unsigned char) buffer[bufferHead];
                bufferHead++;
                if (bufferHead == bufferLength){bufferHead = 0;}

                gridInsertX++;
                if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
            }
            buffer[bufferTail] = 0;
            bufferTail ++;
            if (bufferTail == bufferLength) {bufferTail = 0;}
        }

        nextEnd = (byteWidthPerWorker + 1)-nextEnd;//Calculate start and end metrics
        if (nextEnd >127) {nextEnd = 127;}
        else (nextEnd = nextEnd&127);
        grid[byteWidthPerWorker+1][y-1] = prevEnd;//Store previous start end metrics
        prevEnd = nextEnd;
        grid[0][y-1] = prevStart;
        prevStart = nextStart;

    }
    grid[0][bitHeightPerWorker] = prevStart;//output last start and end metrics
    grid[byteWidthPerWorker+1][bitHeightPerWorker+1] = prevEnd;
    while (bufferHead!=bufferTail)//Flush the Queue into the lifegrid
    {

        grid[gridInsertX][gridInsertY] = (unsigned char) buffer[bufferHead];
        bufferHead++;
        if (bufferHead == bufferLength){bufferHead = 0;}

        gridInsertX++;
        if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
    }
    return aliveCells;
}





//Returns data from worker to distributor
void returnData(lifeGrid, chanend distributor)
{
    unsigned char receivedData = 0;

    for (int y = 1; y < bitHeightPerWorker + 1; y++)
    {
        distributor :> receivedData;
        for (int x = 1; x < byteWidthPerWorker + 1; x++)
        {

            distributor <: grid[x][y];
        }
    }
}

//Calculates game of life for farmer, communicates with neighbours to receive data.
//Transmits signal to farmer when done with iteration.
//Contains while (1)
void worker(chanend distributor, chanend up, chanend down, chanend left, chanend right, char parity)
{
    lifeGrid;
    unsigned char input = 0;
    unsigned int aliveCells = 0;
    while (1)
    {
        distributor <: (unsigned char)0;
        distributor :> input;
        switch (input)
        {
            case 0://Continue
                transferData(grid, up, down, left, right, parity);
                aliveCells = calcGrid(grid);
                break;
            case 1://Load Data
                loadArray(grid, distributor);
                break;
            case 2: //Return data
                returnData(grid, distributor);
                break;
            case 3://return pause data
                distributor <: aliveCells;
                break;

        }
    }

}
