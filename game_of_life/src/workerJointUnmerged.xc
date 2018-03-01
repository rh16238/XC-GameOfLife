#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <stdlib.h>
#include "pgmIO.h"
#include "i2c.h"
#include "definitions.xc"

unsigned int calcGridMax(lifeGrid );
{unsigned int,unsigned int} calcGridSkip(lifeGrid );
void loadArraySkip(lifeGrid , chanend distributor);
void transferDataSkip(lifeGrid, chanend up, chanend down, chanend left, chanend right, char parity);
void transferDataMax(lifeGrid, chanend up, chanend down, chanend left, chanend right, char parity);

//////////////////////////////////////////NOTE////////////////////////////////////////////////////////////////////////
///////////////NOTE:This worker uses merged functions from workerMax and workerMerged, ensure that they  /////////////
///////////////updated if you alter workerSkip and workerMax                                             /////////////
/////////////// Merged functions ensure performance and memory limits, as XC optimizes them poorly       /////////////
///////////////                                                                                          /////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
unsigned char cellAlive (unsigned char neighbours, unsigned char cellAlive)
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
//Ensures a life grid has no incorrect start and end value from workerMax
void convertGridToSkippable(lifeGrid)
{
    for (int y = 0; y++; y<bitHeightPerWorker+2)
    {
        grid [0] [y] = 0;
        grid [byteWidthPerWorker+1] [y] = 0;
    }
}


{int, int, int, int} addToBuffer(lifeGrid, unsigned char buffer[bufferLength], int gridInsertX, int gridInsertY, int bufferHead , int bufferTail, char newData)
{
    int fullTailPosition = bufferHead -1;//check if buffer is full
    if (fullTailPosition < 0) { fullTailPosition = bufferLength-1;}
    if (bufferTail == fullTailPosition)
    {

        grid[gridInsertX][gridInsertY] = (unsigned char) buffer[bufferHead];// if buffer full, pop into lifegrid
        bufferHead++;                                                       //Buffer is long enough to ensure that
        if (bufferHead == bufferLength){bufferHead = 0;}                    // the values are not used until next iteration

        gridInsertX++;
        if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
    }
    buffer[bufferTail] = newData; //Push newbyte onto Queue
    bufferTail ++;
    if (bufferTail == bufferLength) {bufferTail = 0;}
    return {gridInsertX, gridInsertY, bufferHead, bufferTail};
}

void gridFlushBuffer(lifeGrid, unsigned char buffer[bufferLength], int gridInsertX, int gridInsertY, int bufferHead , int bufferTail )
{
    while (bufferHead!=bufferTail)//Flush Buffer
    {
        grid[gridInsertX][gridInsertY] = (unsigned char) buffer[bufferHead];
        bufferHead++;
        if (bufferHead == bufferLength){bufferHead = 0;}

        gridInsertX++;
        if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
    }
}

void calcLeftBitsFull(unsigned char currentByte, unsigned char aboveCurrentByte, unsigned char belowCurrentByte, unsigned char adjacentByte, unsigned char aboveAdjacentByte, unsigned char belowAdjacentByte, unsigned char* currentValue, unsigned int* aliveCells)
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
    *currentValue = tempByte;

}
void calculateMiddleBits(unsigned char currentByte, unsigned char aboveCurrentByte, unsigned char belowCurrentByte, unsigned char* currentValue, unsigned int* aliveCells)
{
    unsigned char cellIsAlive = 0;
    unsigned char neighbours = 0;
    unsigned int livingCells = 0;
    unsigned char tempByte = *currentValue;



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
        *currentValue = tempByte;
    }
    else
    {
        *currentValue = (tempByte)<<6;
    }

}

void calcRightMostBitFull(unsigned char currentByte, unsigned char aboveCurrentByte, unsigned char belowCurrentByte, unsigned char adjacentByte, unsigned char aboveAdjacentByte, unsigned char belowAdjacentByte, unsigned char* currentValue, unsigned int* aliveCells)
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


//Loads the lifeGrid from the distributor
void loadArray(lifeGrid , chanend distributor)
{
    for (int j = 0; j<bitHeightPerWorker; j++)
    {
        for (int i = 0; i<(byteWidthPerWorker); i++)
        {

            distributor :> grid [i+1] [j+1];

        }
    }
}

//Return data to the Distributor
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

void worker(chanend distributor, chanend up, chanend down, chanend left, chanend right, char parity)
{
    lifeGrid;
    char skippedCooldownTimer = 0;
    unsigned char input = 0;
    unsigned int skipped = 0;
    unsigned int skippedMinimum = bitHeightPerWorker * (byteWidthPerWorker * .3);
    unsigned int aliveCells = 0;
    char skip = 0;
    int imageSizeGate = 257-IMHT;//WorkerMax works best at these low values.
    while (1)
    {
        distributor <: (unsigned char)0;
        distributor :> input;
        switch (input)
        {
            case 0://Continue
                if (imageSizeGate)//If image is small use lightweight DataMax
                {
                    transferDataMax(grid, up, down, left, right, parity);
                     aliveCells = calcGridMax(grid);
                }
                else
                {
                    if ((!skip) && (!skippedCooldownTimer))//If we are not skipping and have not tried for a while, try it.
                    {
                        skip = 1;
                        convertGridToSkippable(grid);//Ensure certain values in lifegrid are empty, otherwise unknown starts and ends
                    }
                    else if (skip && (skipped < skippedMinimum) )// if we are skipping but not very many, stop skipping.
                    {
                        skip = 0;
                        skippedCooldownTimer = 30;//Dont skip for this many iterations
                    }

                    if (skip)//If we are skipping
                    {
                        transferDataSkip(grid, up, down, left, right, parity);//Run like worker skip
                        {aliveCells,skippedMinimum} = calcGridSkip(grid);
                    }
                    else// if we are not skipping
                    {
                        transferDataMax(grid, up, down, left, right, parity);// run like worker max
                        aliveCells = calcGridMax(grid);
                    }
                    if (skippedCooldownTimer){skippedCooldownTimer--;}//If we are cooling down, decrement the wait.
                }
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
/////////////////////////////////ONLY MERGED FUNCTIONS FROM WORKER SKIP AND MAX ARE BELOW THIS LINE//////////////////////////////
/////////////////////////////////ONLY MERGED FUNCTIONS FROM WORKER SKIP AND MAX ARE BELOW THIS LINE//////////////////////////////
/////////////////////////////////ONLY MERGED FUNCTIONS FROM WORKER SKIP AND MAX ARE BELOW THIS LINE//////////////////////////////
/////////////////////////////////NO DEVELOPMENT SHOULD BE DONE BELOW THIS LINE. GO TO THE WORKERS //////////////////////////////
/////////////////////////////////NO DEVELOPMENT SHOULD BE DONE BELOW THIS LINE. GO TO THE WORKERS //////////////////////////////
/////////////////////////////////NO DEVELOPMENT SHOULD BE DONE BELOW THIS LINE. GO TO THE WORKERS //////////////////////////////

















//////////////////////WORKER SKIP FUNCTIONS////////////////////////////////////////////
void loadArraySkip(lifeGrid , chanend distributor)
{
    char input = 0;
    char needVal = 1;
    int lastVal = byteWidthPerWorker +1;
    for (int j = 0; j<bitHeightPerWorker; j++)
    {
        grid [0][j+1] = 0;
        grid [byteWidthPerWorker+1][j+1] = 0;
        needVal = 1;
        for (int i = 0; i<(byteWidthPerWorker); i++)
        {

            distributor :> input;
            if (input)
            {
                input ++;
                if (needVal)
                {
                    needVal = 0;
                    if (126 < i){grid [0][j+1] = 254;}//Yes I know this looks wrong but i+1
                    else {grid [0][j+1] = ((i+1)<<1);}

                }
                lastVal = i+1;
            }

            grid [i+1] [j+1] = input;

        }
        lastVal = ((byteWidthPerWorker+1)-lastVal);
        if (lastVal > 127) {lastVal = 127;}
        grid [byteWidthPerWorker+1] [j+1] = lastVal;
    }
}

void transferDataSkip(lifeGrid, chanend up, chanend down, chanend left, chanend right, char parity)
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
                if (input &1) {grid [0] [i + 1]= 3;}
                else {grid [0] [i+1] = grid [0] [i+1] &254;}

                right :> input;
                if (input &128) {grid [byteWidthPerWorker + 1] [i + 1]= 128;}
                else {grid [byteWidthPerWorker + 1] [i + 1] = grid [byteWidthPerWorker + 1] [i + 1] &127;}

            }
        }
        else
        {
            for(int i = 0; i < bitHeightPerWorker; i++)
            {
                right <: grid [byteWidthPerWorker] [i + 1];
                left <: grid [1] [i + 1];
            }
        }
    }

    for(char t = 0; t < 2; t++)//TOP AND BOTTOM BORDERS
    {
        if(parity == t)
        {
            for(int i = 0; i < byteWidthPerWorker; i++)
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

                down :> input;//
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
        else
        {
            for(int i = 0; i < byteWidthPerWorker; i++)
            {
                down <: grid [i + 1] [bitHeightPerWorker];
                up <: grid [i + 1] [1];
            }
        }
    }
    endUpper = ((byteWidthPerWorker + 1)-endUpper);
    if (endUpper > 127) {endUpper = 127;}
    endLower = ((byteWidthPerWorker + 1)-endLower);
    if (endLower > 127) {endLower = 127;}
    for(char t = 0; t < 2; t++)
    {
        if(parity == t)
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
        else
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
{unsigned int,unsigned int}  calcGridSkip(lifeGrid )
{
    unsigned int aliveCells = 0;
    unsigned int* ap = &aliveCells;
    int skipped = 0;
    //Queue Variables
    unsigned char buffer [bufferLength];
    unsigned int bufferHead = 0;
    unsigned int bufferTail = 0;
    unsigned int gridInsertX = 1;
    unsigned int gridInsertY = 1;

    //Data stores
    unsigned char adjacentDataInA = 0;
    unsigned char byteA;
    unsigned char aboveByteA;
    unsigned char belowByteA;
    unsigned char byteB;
    unsigned char aboveByteB;
    unsigned char belowByteB;
    unsigned char newData = 0;
    unsigned char* byteStore = &newData;

    char prevStart = grid[0][0];
    int prevEnd = grid[0][byteWidthPerWorker+1];
    char start = 1;
    unsigned int end = byteWidthPerWorker+1;
    char startNeeded;
    char nextStart;
    int nextEnd;

    for (int y = 1; y < bitHeightPerWorker + 1; y++)//For each row
    {
        adjacentDataInA = 0;//Set flag showing adjacent data is in b.
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
            skipped ++;
            {gridInsertX, gridInsertY, bufferHead, bufferTail} = addToBuffer(grid, buffer, gridInsertX, gridInsertY, bufferHead, bufferTail, 0);
        }

        byteA = grid [1] [y];//Set a to be first byte needing calculation
        aboveByteA = grid [1] [y-1];
        belowByteA = grid [1] [y+1];

        byteB = grid [0] [y];//set b to be left hand byte to A.
        aboveByteB = grid [0] [y-1];
        belowByteB = grid [0] [y+1];




        for (int x = start; x < end; x++)
        {
            newData = 0;
            if(adjacentDataInA)//If adjacent data is in A
            {
                calcLeftBitsFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);
                calculateMiddleBits(byteB, aboveByteB, belowByteB, byteStore, ap);
                //Calculate Left bits
                byteA = grid [x+1] [y];
                aboveByteA = grid [x+1] [y-1];
                belowByteA = grid [x+1] [y+1];
                //Store right hand adjacent data in A
                calcRightMostBitFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);
                //Calculate Rightmost bit
            }
            else//If adjacent data is in B
            {
                calcLeftBitsFull(byteA, aboveByteA, belowByteA, byteB, aboveByteB, belowByteB, byteStore, ap);
                calculateMiddleBits(byteA, aboveByteA, belowByteA, byteStore, ap);
                //Calculate Left bits
                byteB = grid [x+1] [y];
                aboveByteB = grid [x+1] [y-1];
                belowByteB = grid [x+1] [y+1];
                //Store right hand adjacent data in B
                calcRightMostBitFull(byteA, aboveByteA, belowByteA, byteB, aboveByteB, belowByteB, byteStore, ap);
                //Calculate Rightmost bit
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

            adjacentDataInA = !adjacentDataInA;//Whichever byte stores righthand adjacent data is now the new current byte

            {gridInsertX, gridInsertY, bufferHead, bufferTail} = addToBuffer(grid, buffer, gridInsertX, gridInsertY, bufferHead, bufferTail, newData);

        }
        for (int x = end; x < byteWidthPerWorker+1; x++)
        {
            skipped ++;
            {gridInsertX, gridInsertY, bufferHead, bufferTail} = addToBuffer(grid, buffer, gridInsertX, gridInsertY, bufferHead, bufferTail, 0);
        }

        nextEnd = (byteWidthPerWorker + 1)-nextEnd;//Calculate start and end metrics
        if (nextEnd >127) {nextEnd = 127;}
        else nextEnd = nextEnd&127;
        grid[byteWidthPerWorker+1][y-1] = prevEnd;//Store previous start end metrics
        prevEnd = nextEnd;
        grid[0][y-1] = prevStart;
        prevStart = nextStart;

    }
    grid[0][bitHeightPerWorker] = prevStart;//output last start and end metrics
    grid[byteWidthPerWorker+1][bitHeightPerWorker+1] = prevEnd;

    gridFlushBuffer(grid, buffer, gridInsertX, gridInsertY, bufferHead, bufferTail);
    return {aliveCells,skipped};
}

/////////////////////////WORKER MAX FUNCTIONS/////////////////////////////
void transferDataMax(lifeGrid, chanend up, chanend down, chanend left, chanend right, char parity)
{
    for(char t = 0; t < 2; t++)//LEFT AND RIGHT BORDERS
    {
        if(parity == t)
        {
            for(int i = 0; i < bitHeightPerWorker; i++)
            {
                left :> grid [0] [i + 1];
                right :> grid [byteWidthPerWorker + 1] [i + 1];

            }
        }
        else
        {
            for(int i = 0; i < bitHeightPerWorker; i++)
            {
                right <: grid [byteWidthPerWorker] [i + 1];
                left <: grid [1] [i + 1];
            }
        }
    }

    for(char t = 0; t < 2; t++)//TOP AND BOTTOM BORDERS
    {
        if(parity == t)
        {
            for(int i = 0; i < byteWidthPerWorker; i++)
            {
                up :> grid [i + 1] [0];
                down :> grid [i + 1] [bitHeightPerWorker + 1];//

            }
        }
        else
        {
            for(int i = 0; i < byteWidthPerWorker; i++)
            {
                down <: grid [i + 1] [bitHeightPerWorker];
                up <: grid [i + 1] [1];
            }
        }
    }

    for(char t = 0; t < 2; t++)
    {
        if(parity == t)
        {
            left :> grid [0] [0];
            left :> grid [0] [bitHeightPerWorker+1];

            right :> grid [(byteWidthPerWorker)+1] [0];


            right :> grid [(byteWidthPerWorker)+1] [bitHeightPerWorker+1];
        }
        else
        {
            right <: grid [(byteWidthPerWorker)] [0];
            right <: grid [(byteWidthPerWorker)] [bitHeightPerWorker+1];

            left <: grid [1] [0];
            left <: grid [1] [bitHeightPerWorker+1];
        }
    }

}


unsigned int calcGridMax(lifeGrid )
{
    unsigned int aliveCells = 0;
    unsigned int* ap = &aliveCells;

    //Queue Variables
    unsigned char buffer [bufferLength];
    unsigned int bufferHead = 0;
    unsigned int bufferTail = 0;
    unsigned int gridInsertX = 1;
    unsigned int gridInsertY = 1;

    //Data stores
    unsigned char adjacentDataInA = 0;
    unsigned char byteA;
    unsigned char aboveByteA;
    unsigned char belowByteA;
    unsigned char byteB;
    unsigned char aboveByteB;
    unsigned char belowByteB;
    unsigned char newData = 0;
    unsigned char* byteStore = &newData;

    for (int y = 1; y < bitHeightPerWorker + 1; y++)//For each row
    {
        byteA = grid [1] [y];//Set a to be first byte needing calculation
        aboveByteA = grid [1] [y-1];
        belowByteA = grid [1] [y+1];

        byteB = grid [0] [y];//set b to be left hand byte to A.
        aboveByteB = grid [0] [y-1];
        belowByteB = grid [0] [y+1];

        adjacentDataInA = 0;//Set flag showing adjacent data is in b.
        for (int x = 1; x < byteWidthPerWorker + 1; x++)
        {
            newData = 0;
            if(adjacentDataInA)//If adjacent data is in A
            {
                calcLeftBitsFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);
                calculateMiddleBits(byteB, aboveByteB, belowByteB, byteStore, ap);
                //Calculate Left bits
                byteA = grid [x+1] [y];
                aboveByteA = grid [x+1] [y-1];
                belowByteA = grid [x+1] [y+1];
                //Store right hand adjacent data in A
                calcRightMostBitFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);
                //Calculate Rightmost bit
            }
            else//If adjacent data is in B
            {
                calcLeftBitsFull(byteA, aboveByteA, belowByteA, byteB, aboveByteB, belowByteB, byteStore, ap);
                calculateMiddleBits(byteA, aboveByteA, belowByteA, byteStore, ap);
                //Calculate Left bits
                byteB = grid [x+1] [y];
                aboveByteB = grid [x+1] [y-1];
                belowByteB = grid [x+1] [y+1];
                //Store right hand adjacent data in B
                calcRightMostBitFull(byteA, aboveByteA, belowByteA, byteB, aboveByteB, belowByteB, byteStore, ap);
                //Calculate Rightmost bit
            }

            adjacentDataInA = !adjacentDataInA;//Whichever byte stores righthand adjacent data is now the new current byte
            {gridInsertX, gridInsertY, bufferHead, bufferTail} = addToBuffer(grid, buffer, gridInsertX, gridInsertY, bufferHead, bufferTail, newData);

        }
    }
    gridFlushBuffer(grid, buffer, gridInsertX, gridInsertY, bufferHead, bufferTail);
    return aliveCells;
}

