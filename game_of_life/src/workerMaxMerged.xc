#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <stdlib.h>
#include "pgmIO.h"
#include "i2c.h"
#include "definitions.xc"

////////////////////////THIS FILE IS FOR EXECUTION////////////////////////////////////////
//////////////////////THIS FILE IS NOT FOR DEVELOPING/////////////////////////////////////
/// This file is to solve the fact that XC cannot effieciently handle function calls   ///
/// so to ensure performance and memory usage limits, I have had to manually merge the ///
/// functions that get called into where they are called. This leads to large, hard to ///
/// read functions.                                                                    ///
///                                                                                    ///
/// All developing should take place in workerMax, and then this file should be        ///
/// reconstructed from it once the changes have been proven to work.                   ///
///                                                                                    ///
///                         YOU HAVE BEEN WARNED.                                      ///
//////////////////////////////////////////////////////////////////////////////////////////





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

void transferData(lifeGrid, chanend up, chanend down, chanend left, chanend right, char parity)
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







unsigned int calcGrid(lifeGrid,char opt )
{
    unsigned char currentByte;
    unsigned char aboveCurrentByte;
    unsigned char belowCurrentByte;
    unsigned char cellIsAlive = 0;
    unsigned char neighbours = 0;
    //   char opt = 1;
    unsigned int aliveCells = 0;
    unsigned int* ap = &aliveCells;
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
    unsigned char* byteStore = &newData;

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
    unsigned char input = 0;
    unsigned int aliveCells = 0;
    while (1)
    {
        //  printf("Worker Awaiting instruction");
        distributor <: (unsigned char)0;
        distributor :> input;
        switch (input)
        {
            case 0://Continue
                transferData(grid, up, down, left, right, parity);

                aliveCells = calcGrid(grid,1);
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

