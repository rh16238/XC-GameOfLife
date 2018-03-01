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

//Ensures a life grid has no incorrect start and end value from workerMax
void convertGridToSkippable(lifeGrid)
{
    for (int y = 0; y++; y<bitHeightPerWorker+2)
    {
        grid [0] [y] = 0;
        grid [byteWidthPerWorker+1] [y] = 0;
    }
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



{unsigned int,unsigned int} calcGridSkip(lifeGrid )
{
    unsigned int skipped = 0;
    unsigned char cellIsAlive = 0;
    unsigned char neighbours = 0;
    unsigned int aliveCells = 0;

    unsigned char buffer [bufferLength];
    unsigned int bufferHead = 0;
    unsigned int bufferTail = 0;
    unsigned int gridInsertX = 1;
    unsigned int gridInsertY = 1;
    int fullTailPosition;

    unsigned char adjacentDataInA = 0;
    unsigned char byteA;
    unsigned char aboveByteA;
    unsigned char belowByteA;

    unsigned char byteB;
    unsigned char aboveByteB;
    unsigned char belowByteB;

    unsigned char currentByte;
    unsigned char aboveCurrentByte;
    unsigned char belowCurrentByte;
    unsigned char newData = 0;
    char prevStart = grid[0][0];
    int prevEnd = grid[0][byteWidthPerWorker+1];
    char start = 1;
    unsigned int end = byteWidthPerWorker+1;
    char startNeeded;
    char nextStart;
    int nextEnd;
    for (int y = 1; y < bitHeightPerWorker + 1; y++)
    {

        adjacentDataInA = 0;
        startNeeded = 1;
        nextStart = 254;
        nextEnd = 0;

        start = (grid [0] [y-1])>>1;
        newData = grid [0][y]>>1;
        if (start > newData){start = newData;}
        newData = grid [0][y+1]>>1;
        if (start > newData){start = newData;}
        if (start > byteWidthPerWorker+1) { start = byteWidthPerWorker+1;}
        if (start < 2) {start = 1;}
        else {start--;}

        end =  grid [byteWidthPerWorker+1] [y-1] & 127;
        newData = grid [byteWidthPerWorker+1] [y] &127;
        if (end > newData){end = newData;}
        newData = grid [byteWidthPerWorker+1] [y+1] & 127;
        if (end > newData){end = newData;}
        end = ((byteWidthPerWorker+1) -end)+2;
        if (end > byteWidthPerWorker){end = byteWidthPerWorker+1;}
        if (start > end) {end = start;}

        for (int x = 1; x < start; x++)
        {
            //  if (grid[x][y]){printf("ERROR %d of %d\n",x,start);}
            skipped ++;
            fullTailPosition = bufferHead -1;
            if (fullTailPosition < 0) { fullTailPosition = bufferLength-1;}
            if (bufferTail == fullTailPosition)
            {
                grid[gridInsertX][gridInsertY] =  buffer[bufferHead];
                bufferHead++;
                if (bufferHead == bufferLength){bufferHead = 0;}

                gridInsertX++;
                if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
            }
            buffer[bufferTail] = 0;
            bufferTail ++;
            if (bufferTail == bufferLength) {bufferTail = 0;}

        }
        if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
        // start = 1;

        byteA = grid [start] [y];
        aboveByteA = grid [start] [y-1];
        belowByteA = grid [start] [y+1];

        byteB = grid [start-1] [y];
        aboveByteB = grid [start-1] [y-1];
        belowByteB = grid [start-1] [y+1];
        for (int x = start; x < end; x++)
        {

            newData = 0;

            if(adjacentDataInA)
            {
                currentByte = byteB;
                aboveCurrentByte = aboveByteB;
                belowCurrentByte = belowByteB;
                ////////CALC LEFT BITS//////////////
                // calcLeftMostBitFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);

                neighbours = (currentByte &64) >> 6;
                neighbours += (aboveCurrentByte &64)  >> 6;
                neighbours += (belowCurrentByte &64)  >> 6;

                neighbours += (aboveCurrentByte &128) >> 7;
                neighbours += (belowCurrentByte &128) >> 7;

                neighbours += byteA &1;
                neighbours += aboveByteA &1;
                neighbours += belowByteA &1;

                if (neighbours >3){cellIsAlive = 0;}
                else if (currentByte &128)
                {
                    if (neighbours < 2) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                else
                {
                    if (neighbours < 3) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                //cellIsAlive = cellAlive(neighbours, currentByte &128);
                newData = cellIsAlive;
                aliveCells+= cellIsAlive;



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

                        if (neighbours >3){cellIsAlive = 0;}
                        else if (currentByte &64)
                        {
                            if (neighbours < 2) {cellIsAlive = 0;}
                            else cellIsAlive = 1;
                        }
                        else
                        {
                            if (neighbours < 3) {cellIsAlive = 0;}
                            else cellIsAlive = 1;
                        }

                        //cellIsAlive = cellAlive(neighbours, currentByte & 64);
                        newData = (newData<<1)|cellIsAlive;
                        aliveCells += cellIsAlive;

                        currentByte = currentByte<<1;
                        aboveCurrentByte = aboveCurrentByte<<1;
                        belowCurrentByte = belowCurrentByte<<1;
                    }


                }
                else
                {
                    newData = (newData)<<6;
                }
                ////////END OF LEFT BIT CALCULATION
                byteA = grid [x+1] [y];
                aboveByteA = grid [x+1] [y-1];
                belowByteA = grid [x+1] [y+1];

                //////// CALCULATE RIGHTMOST BIT
                neighbours = (byteB &2)>>1;
                neighbours += (aboveByteB &2)>>1;
                neighbours += (belowByteB &2) >>1;

                neighbours += aboveByteB &1;
                neighbours += belowByteB &1;

                neighbours += (byteA &128)>>7;
                neighbours += (aboveByteA &128)>>7;
                neighbours += (belowByteA &128)>>7;

                if (neighbours >3){cellIsAlive = 0;}
                else if (byteB &1)
                {
                    if (neighbours < 2) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                else
                {
                    if (neighbours < 3) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                //cellIsAlive = cellAlive(neighbours, currentByte &1);
                newData = (newData << 1)|cellIsAlive ;
                aliveCells += cellIsAlive;
                ////////END OF CALCULATION
                // calcRightMostBitFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);

            }
            else
            {
                currentByte = byteA;
                aboveCurrentByte = aboveByteA;
                belowCurrentByte = belowByteA;
                ////////CALC LEFT BITS//////////////
                // calcLeftMostBitFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);

                neighbours = (currentByte &64) >> 6;
                neighbours += (aboveCurrentByte &64)  >> 6;
                neighbours += (belowCurrentByte &64)  >> 6;

                neighbours += (aboveCurrentByte &128) >> 7;
                neighbours += (belowCurrentByte &128) >> 7;

                neighbours += byteB &1;
                neighbours += aboveByteB &1;
                neighbours += belowByteB &1;

                if (neighbours >3){cellIsAlive = 0;}
                else if (currentByte &128)
                {
                    if (neighbours < 2) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                else
                {
                    if (neighbours < 3) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                //cellIsAlive = cellAlive(neighbours, currentByte &128);
                newData = cellIsAlive;
                aliveCells+= cellIsAlive;



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

                        if (neighbours >3){cellIsAlive = 0;}
                        else if (currentByte &64)
                        {
                            if (neighbours < 2) {cellIsAlive = 0;}
                            else cellIsAlive = 1;
                        }
                        else
                        {
                            if (neighbours < 3) {cellIsAlive = 0;}
                            else cellIsAlive = 1;
                        }

                        //cellIsAlive = cellAlive(neighbours, currentByte & 64);
                        newData = (newData<<1)|cellIsAlive;
                        aliveCells += cellIsAlive;

                        currentByte = currentByte<<1;
                        aboveCurrentByte = aboveCurrentByte<<1;
                        belowCurrentByte = belowCurrentByte<<1;
                    }


                }
                else
                {
                    newData = (newData)<<6;
                }
                ////////END OF LEFT BIT CALCULATION
                byteB = grid [x+1] [y];
                aboveByteB = grid [x+1] [y-1];
                belowByteB = grid [x+1] [y+1];

                //////// CALCULATE RIGHTMOST BIT
                neighbours = (byteA &2)>>1;
                neighbours += (aboveByteA &2)>>1;
                neighbours += (belowByteA &2) >>1;

                neighbours += aboveByteA &1;
                neighbours += belowByteA &1;

                neighbours += (byteB &128)>>7;
                neighbours += (aboveByteB &128)>>7;
                neighbours += (belowByteB &128)>>7;

                if (neighbours >3){cellIsAlive = 0;}
                else if (byteA &1)
                {
                    if (neighbours < 2) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                else
                {
                    if (neighbours < 3) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                //cellIsAlive = cellAlive(neighbours, currentByte &1);
                newData = (newData << 1)|cellIsAlive ;
                aliveCells += cellIsAlive;
                ////////END OF CALCULATION


            }
            if (newData)
            {
                if (startNeeded)
                {
                    startNeeded = 0;
                    if (x > 127) {nextStart = 254;}
                    else {nextStart = x <<1;}

                }
                nextEnd = x;
            }
            adjacentDataInA = !adjacentDataInA;

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
            buffer[bufferTail] = newData;
            bufferTail ++;
            if (bufferTail == bufferLength) {bufferTail = 0;}

        }
        for (int x = end; x < byteWidthPerWorker+1; x++)
        {
            //    printf("END LOOP %d\n",end);
            // if (grid [x][y]){printf("ERROR AT END, %d past %d on row %d\n", x, end, y);}
            skipped ++;
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

        nextEnd = (byteWidthPerWorker + 1)-nextEnd;
        if (nextEnd >127) {nextEnd = 127;}
        else (nextEnd = nextEnd&127);
        grid[byteWidthPerWorker+1][y-1] = prevEnd;
        prevEnd = nextEnd;


        grid[0][y-1] = prevStart;
        prevStart = nextStart;

    }
    grid[0][bitHeightPerWorker] = prevStart;
    grid[byteWidthPerWorker+1][bitHeightPerWorker+1] = prevEnd;
    while (bufferHead!=bufferTail)
    {

        grid[gridInsertX][gridInsertY] = (unsigned char) buffer[bufferHead];
        bufferHead++;
        if (bufferHead == bufferLength){bufferHead = 0;}

        gridInsertX++;
        if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
    }
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
    unsigned char currentByte;
    unsigned char aboveCurrentByte;
    unsigned char belowCurrentByte;
    unsigned char cellIsAlive = 0;
    unsigned char neighbours = 0;

    unsigned int aliveCells = 0;

    unsigned char buffer [bufferLength];
    unsigned int bufferHead = 0;
    unsigned int bufferTail = 0;
    unsigned int gridInsertX = 1;
    unsigned int gridInsertY = 1;

    unsigned char adjacentDataInA = 0;
    unsigned char byteA;
    unsigned char aboveByteA;
    unsigned char belowByteA;

    unsigned char byteB;
    unsigned char aboveByteB;
    unsigned char belowByteB;
    unsigned char newData = 0;

    for (int y = 1; y < bitHeightPerWorker + 1; y++)
    {
        byteA = grid [1] [y];
        aboveByteA = grid [1] [y-1];
        belowByteA = grid [1] [y+1];

        byteB = grid [0] [y];
        aboveByteB = grid [0] [y-1];
        belowByteB = grid [0] [y+1];

        adjacentDataInA = 0;
        for (int x = 1; x < byteWidthPerWorker + 1; x++)
        {
            newData = 0;

            if(adjacentDataInA)
            {
                currentByte = byteB;
                aboveCurrentByte = aboveByteB;
                belowCurrentByte = belowByteB;
                ////////CALC LEFT BITS//////////////
                // calcLeftMostBitFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);

                neighbours = (currentByte &64) >> 6;
                neighbours += (aboveCurrentByte &64)  >> 6;
                neighbours += (belowCurrentByte &64)  >> 6;

                neighbours += (aboveCurrentByte &128) >> 7;
                neighbours += (belowCurrentByte &128) >> 7;

                neighbours += byteA &1;
                neighbours += aboveByteA &1;
                neighbours += belowByteA &1;

                if (neighbours >3){cellIsAlive = 0;}
                else if (currentByte &128)
                {
                    if (neighbours < 2) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                else
                {
                    if (neighbours < 3) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                //cellIsAlive = cellAlive(neighbours, currentByte &128);
                newData = cellIsAlive;
                aliveCells+= cellIsAlive;



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

                        if (neighbours >3){cellIsAlive = 0;}
                        else if (currentByte &64)
                        {
                            if (neighbours < 2) {cellIsAlive = 0;}
                            else cellIsAlive = 1;
                        }
                        else
                        {
                            if (neighbours < 3) {cellIsAlive = 0;}
                            else cellIsAlive = 1;
                        }

                        //cellIsAlive = cellAlive(neighbours, currentByte & 64);
                        newData = (newData<<1)|cellIsAlive;
                        aliveCells += cellIsAlive;

                        currentByte = currentByte<<1;
                        aboveCurrentByte = aboveCurrentByte<<1;
                        belowCurrentByte = belowCurrentByte<<1;
                    }


                }
                else
                {
                    newData = (newData)<<6;
                }
                ////////END OF LEFT BIT CALCULATION
                byteA = grid [x+1] [y];
                aboveByteA = grid [x+1] [y-1];
                belowByteA = grid [x+1] [y+1];

                //////// CALCULATE RIGHTMOST BIT
                neighbours = (byteB &2)>>1;
                neighbours += (aboveByteB &2)>>1;
                neighbours += (belowByteB &2) >>1;

                neighbours += aboveByteB &1;
                neighbours += belowByteB &1;

                neighbours += (byteA &128)>>7;
                neighbours += (aboveByteA &128)>>7;
                neighbours += (belowByteA &128)>>7;

                if (neighbours >3){cellIsAlive = 0;}
                else if (byteB &1)
                {
                    if (neighbours < 2) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                else
                {
                    if (neighbours < 3) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                //cellIsAlive = cellAlive(neighbours, currentByte &1);
                newData = (newData << 1)|cellIsAlive ;
                aliveCells += cellIsAlive;
                ////////END OF CALCULATION
                // calcRightMostBitFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);

            }
            else
            {
                currentByte = byteA;
                aboveCurrentByte = aboveByteA;
                belowCurrentByte = belowByteA;
                ////////CALC LEFT BITS//////////////
                // calcLeftMostBitFull(byteB, aboveByteB, belowByteB, byteA, aboveByteA, belowByteA, byteStore, ap);

                neighbours = (currentByte &64) >> 6;
                neighbours += (aboveCurrentByte &64)  >> 6;
                neighbours += (belowCurrentByte &64)  >> 6;

                neighbours += (aboveCurrentByte &128) >> 7;
                neighbours += (belowCurrentByte &128) >> 7;

                neighbours += byteB &1;
                neighbours += aboveByteB &1;
                neighbours += belowByteB &1;

                if (neighbours >3){cellIsAlive = 0;}
                else if (currentByte &128)
                {
                    if (neighbours < 2) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                else
                {
                    if (neighbours < 3) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                //cellIsAlive = cellAlive(neighbours, currentByte &128);
                newData = cellIsAlive;
                aliveCells+= cellIsAlive;



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

                        if (neighbours >3){cellIsAlive = 0;}
                        else if (currentByte &64)
                        {
                            if (neighbours < 2) {cellIsAlive = 0;}
                            else cellIsAlive = 1;
                        }
                        else
                        {
                            if (neighbours < 3) {cellIsAlive = 0;}
                            else cellIsAlive = 1;
                        }

                        //cellIsAlive = cellAlive(neighbours, currentByte & 64);
                        newData = (newData<<1)|cellIsAlive;
                        aliveCells += cellIsAlive;

                        currentByte = currentByte<<1;
                        aboveCurrentByte = aboveCurrentByte<<1;
                        belowCurrentByte = belowCurrentByte<<1;
                    }


                }
                else
                {
                    newData = (newData)<<6;
                }
                ////////END OF LEFT BIT CALCULATION
                byteB = grid [x+1] [y];
                aboveByteB = grid [x+1] [y-1];
                belowByteB = grid [x+1] [y+1];

                //////// CALCULATE RIGHTMOST BIT
                neighbours = (byteA &2)>>1;
                neighbours += (aboveByteA &2)>>1;
                neighbours += (belowByteA &2) >>1;

                neighbours += aboveByteA &1;
                neighbours += belowByteA &1;

                neighbours += (byteB &128)>>7;
                neighbours += (aboveByteB &128)>>7;
                neighbours += (belowByteB &128)>>7;

                if (neighbours >3){cellIsAlive = 0;}
                else if (byteA &1)
                {
                    if (neighbours < 2) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                else
                {
                    if (neighbours < 3) {cellIsAlive = 0;}
                    else cellIsAlive = 1;
                }
                //cellIsAlive = cellAlive(neighbours, currentByte &1);
                newData = (newData << 1)|cellIsAlive ;
                aliveCells += cellIsAlive;
                ////////END OF CALCULATION
                /* calcLeftMostBitFull(byteA, aboveByteA, belowByteA, byteB, aboveByteB, belowByteB, byteStore, ap);


                           byteB = grid [x+1] [y];
                           aboveByteB = grid [x+1] [y-1];
                           belowByteB = grid [x+1] [y+1];

                           calcRightMostBitFull(byteA, aboveByteA, belowByteA, byteB, aboveByteB, belowByteB, byteStore, ap);*/

            }

            adjacentDataInA = !adjacentDataInA;

            int fullTailPosition = bufferHead -1;
            if (fullTailPosition < 0) { fullTailPosition = bufferLength-1;}
            if (bufferTail == fullTailPosition)
            {

                grid[gridInsertX][gridInsertY] = (unsigned char) buffer[bufferHead];
                bufferHead++;
                if (bufferHead == bufferLength){bufferHead = 0;}

                gridInsertX++;
                if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
            }
            buffer[bufferTail] = newData;
            bufferTail ++;
            if (bufferTail == bufferLength) {bufferTail = 0;}

        }
    }


    while (bufferHead!=bufferTail)
    {
        grid[gridInsertX][gridInsertY] = (unsigned char) buffer[bufferHead];
        bufferHead++;
        if (bufferHead == bufferLength){bufferHead = 0;}

        gridInsertX++;
        if (gridInsertX == byteWidthPerWorker + 1) { gridInsertX = 1; gridInsertY++;}
    }
    return aliveCells;
}

