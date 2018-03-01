#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <stdlib.h>
#include "pgmIO.h"
#include "definitions.xc"


//returns if cell is alive given its number of neighbours.
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

//Takes a byte, and its vertical and left hand neighbours, and calculates all but the rightmost bit for that byte
//Takes a pointer to a byte and uses that as its output.
//Takes a pointer to an int and increments it for each live cell it encounters.
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

void transferRight(lifeGrid, chanend right, chanend left, char parity)
{
    for(char t = 0; t < 2; t++)
    {
        if(parity == t)
        {
            for(int i = 0; i < bitHeightPerWorker; i++)
            {
                left :> grid [0] [i + 1];
            }
        }
        else
        {
            for(int i = 0; i < bitHeightPerWorker; i++)
            {
                right <: grid [byteWidthPerWorker] [i + 1];
            }
        }
    }
}


void transferLeft(lifeGrid, chanend left, chanend right, char parity)
{
    for(char t = 0; t < 2; t++)
    {
        if(parity == t)
        {
            for(int i = 0; i < bitHeightPerWorker; i++)
            {
                right :> grid [byteWidthPerWorker + 1] [i + 1];
            }
        }
        else
        {
            for(int i = 0; i < bitHeightPerWorker; i++)
            {
                left <: grid [1] [i + 1];
            }
        }
    }
}

void transferDown(lifeGrid, chanend down, chanend up, char parity)
{
    for(char t = 0; t < 2; t++)
    {
        if(parity == t)
        {
            for(int i = 0; i < byteWidthPerWorker; i++)
            {
                up :> grid [i + 1] [0];
            }
        }
        else
        {
            for(int i = 0; i < byteWidthPerWorker; i++)
            {
                down <: grid [i + 1] [bitHeightPerWorker];
            }
        }
    }
}

void transferUp(lifeGrid, chanend up, chanend down, char parity)
{
    for(char t = 0; t < 2; t++)
    {
        if(parity == t)
        {
            for(int i = 0; i < byteWidthPerWorker; i++)
            {
                down :> grid [i + 1] [bitHeightPerWorker + 1];
            }
        }
        else
        {
            for(int i = 0; i < byteWidthPerWorker; i++)
            {
                up <: grid [i + 1] [1];
            }
        }
    }
}

void transferDiagonalRight(lifeGrid, chanend right, chanend left, char parity)
{
    for(char t = 0; t < 2; t++)
    {
        if(parity == t)
        {
            left :> grid [0] [0];
            left :> grid [0] [bitHeightPerWorker+1];
        }
        else
        {
            right <: grid [(byteWidthPerWorker)] [0];
            right <: grid [(byteWidthPerWorker)] [bitHeightPerWorker+1];
        }
    }
}

void transferDiagonalLeft(lifeGrid, chanend left, chanend right, char parity)
{
    for(char t = 0; t < 2; t++)
    {
        if(parity == t)
        {
            right :> grid [(byteWidthPerWorker)+1] [0];
            right :> grid [(byteWidthPerWorker)+1] [bitHeightPerWorker+1];
        }
        else
        {
            left <: grid [1] [0];
            left <: grid [1] [bitHeightPerWorker+1];
        }
    }
}

//Handles transfer of data between neighbours
void transferData(lifeGrid, chanend up, chanend down, chanend left, chanend right, char parity)
{
    transferRight(grid, right, left, parity);//Retrive all adjacent bytes bar corners
    transferLeft(grid, left, right, parity);
    transferDown(grid, down, up, parity);
    transferUp(grid, up, down, parity);
    transferDiagonalRight(grid, right, left, parity);//You now know the corners you neighbours need, so share them.
    transferDiagonalLeft(grid, left, right, parity);

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
//Calculates another iteration of the lifeGrid
//returns number of live cells
//Maintains internal Queue within buffer
unsigned int calcGrid(lifeGrid )
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

//Outputs entire grid for debugging.
void printEntireGrid(lifeGrid, chanend dis)
{
    int test = 0;
    dis :> test;
    for(int y = 0; y < bitHeightPerWorker+2; y++)
    {
        printf("\n");
        for(int x = 0; x < byteWidthPerWorker+2; x++)
        {
            printf(" %d ", grid [x] [y]);
        }

    }
    printf("\n");
    dis<:0;
}

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
