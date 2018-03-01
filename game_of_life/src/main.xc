// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <stdlib.h>
#include "pgmIO.h"
#include "i2c.h"
#include "definitions.xc"
#include "IO.xc"
#include "workerJoint.xc" //WORKER SELECTION. 'Actual Build' WorkerJoint

typedef unsigned char uchar;



const int  threads = 8;
const int tiles = 2;

//Retrieves and Returns all output from 2 Workers who are jointly responsible for rows of the image
//Outputs in form suitable for pgm.
void outputChannels(chanend output, chanend workerLeft, chanend workerRight)
{

    unsigned char input = 0;
    for (int i = 0; i < bitHeightPerWorker; i++)
    {
        workerLeft<: (unsigned char)1;
        for (int x = 0; x < byteWidthPerWorker; x++)
        {
            workerLeft :> input;
            for (int i = 0; i < 8; i++)
            {

                if ((input >> (7-i)) & 1) {output <: (unsigned char)255;}
                else {output <: (unsigned char)0;}
            }
        }
        workerRight<:(unsigned char) 1;
        for (int k = 0; k < byteWidthPerWorker; k++)
        {
            workerRight :> input;
            for (int i = 0; i < 8; i++)
            {

                if ((input >> (7-i)) & 1) {output <: (unsigned char)255;}
                else {output <: (unsigned char)0;}
            }
        }
    }
}

//Retrieves all output from workers and transmits to output chanend in format suitable for pgm
void outputData(chanend output, chanend workerChannels [workersWidth] [workersHeight])
{
    unsigned char input = 0;
    output <: (unsigned char) 1;

    for (int y = 0; y < workersHeight; y++ )
    {
        workerChannels[0][y] :> input;
        workerChannels[1][y] :> input;
        workerChannels[0][y] <: (unsigned char)2;
        workerChannels[1][y] <: (unsigned char)2;
        outputChannels(output, workerChannels [0] [y], workerChannels [1] [y]);


    }
}

//Queries all workers for the number of living cells within them.
unsigned int retrieveLivingCells(chanend workerChannels [workersWidth] [workersHeight])
{
    unsigned int livingCells = 0;
    unsigned int input = 0;
    for (int y = 0; y < workersHeight; y++)
    {
        workerChannels[0][y] :> input;
        livingCells += input;
        workerChannels[1][y] :> input;
        livingCells += input;
    }
    return livingCells;
}

//Tells worker chanends to iterate another round.
void iterateGame(chanend workerChannels[workersWidth][workersHeight])
{

    unsigned char input = 0;
    workerChannels[1][0] :> input;
    for (int y = 1; y < workersHeight; y++ )
    {
        workerChannels[0][y] :> input;
        workerChannels[1][y] :> input;


    }
    for (int y = 0; y < workersHeight; y++ )
    {
        workerChannels[0][y] <: (unsigned char)0;
        workerChannels[1][y] <: (unsigned char)0;

    }
}

//Retrieves a row of pgm bytes from c_in and distributes to workers, packed into bytes.
//Returns number of living bytes within row.
unsigned int distributeRow(chanend c_in, chanend workerChannels[workersWidth] [workersHeight],int yw )
{
    unsigned int livingCells = 0;
    unsigned char val = 0;
    int xw = 0;
    int w = 0;
    int bit = 0;
    unsigned char pack = 0;
    for( int x = 0; x < IMWD; x++ )
    {
        c_in :> val;
        pack = (pack << 1) | (val & 1);
        livingCells += (val &1);
        bit++;
        if(bit == 8)
        {
            workerChannels [xw] [yw] <: pack;
            bit = 0;
            pack = 0;
        }

        w++;
        if(w == bitWidthPerWorker)
        {
            if(bit>0)
                workerChannels [xw] [yw] <: pack;
            w = 0;
            bit = 0;
            pack =0;
            xw ++;
        }

    }
    return livingCells;
}

//Transmits all input from c_in to workers, assuming it matches size of grid in settings.
//Returns number of live cells within initial grid.
unsigned int distributeInput(chanend c_in, chanend workerChannels[workersWidth] [workersHeight])
{
    unsigned int cellsAlive = 0;
    c_in <: (unsigned char) 0;

    int yw = 0;
    int e = 0;

    for( int y = 0; y < IMHT; y++ )
    {

        cellsAlive += distributeRow(c_in, workerChannels, yw);

        e++;
        if(e == bitHeightPerWorker)
        {
            e = 0;
            yw ++;
        }

    }
    return cellsAlive;
}

//Transmits a value to all workers in accordance to protocol.
void transmitToWorkers(unsigned char value, chanend workerChannels [workersWidth] [workersHeight])
{
    unsigned char input = 0;
    for (int y = 0; y < workersHeight; y++ )
    {
        workerChannels[0][y] :> input;
        workerChannels[1][y] :> input;
        workerChannels[0][y] <: value;
        workerChannels[1][y] <: value;
    }
}

//Transmits signal to light leds;
void transmitLED(int led, chanend c_IO)
{
    c_IO <: (unsigned char)2;
    c_IO <: led;
}


// Acts as farmer to workers for game of life. Communicates with workers only when they signal they are ready.
// Responsible for communicating with IO.
//Contains while(1)
void distributor(chanend c_IO, chanend fromAcc, chanend fromButtons, chanend workerChannels [workersWidth] [workersHeight])
{
    unsigned int roundsProcessed = 0;
    unsigned int livingCells = 0;
    unsigned int roundMark = iterationFrequency;//Used to reduce output while still signalling every 100 rounds completed

    timer iterationTimer;
    uint32_t seconds = 0;
    uint32_t minutes = 0;
    uint32_t nextTickMark = 0;
    uint32_t prevTickMark = 0;
    uint32_t tickDifference = 0;
    uint32_t tickInput = 0;
    uchar timerRolloverFlag = 0;

    uchar input = 0;
    uchar running = 1;
    uchar processingOngoing = 0;
    int LedOutput = 0;
    uchar greenLedOn = 0;
    printf("Please press button 1 to load image \n");

    while (1)
    {
        [[ordered]]
         select{

             case fromAcc :> input://Read accelerometer input
                 if (!processingOngoing){break;} //If we are not processing ignore it.
                 if (running)//If we are processing and not paused
                 {
                     iterationTimer :> tickInput;
                     if (timerRolloverFlag)
                     {
                         tickDifference = nextTickMark + (tickInput - prevTickMark);
                     }
                     else
                     {
                         tickDifference = nextTickMark - tickInput;
                     }//Store time difference so runtime metric remains accurate
                     LedOutput = JointLedRed;//output Red led.
                     transmitLED(LedOutput, c_IO);
                     running = 0;//Pause

                     printf("==========PAUSED==========\n");
                     if (roundsProcessed > 0)
                     {
                         transmitToWorkers((unsigned char)3, workerChannels);//Inform workers we are looking for metrics
                         livingCells = retrieveLivingCells(workerChannels);//Retrieve livingCells
                     }
                     printf("Rounds Processed: %d\n", roundsProcessed);
                     printf("Living Cells: %d\n", livingCells);
                     printf("Total execution time since loading: %d:%d.%-9d \n", minutes, seconds, tickDifference);


                 }
                 else
                 {
                     LedOutput = 0;
                     transmitLED(LedOutput, c_IO);
                     running = 1;//unpause

                     printf("==========RESUMED==========\n");
                     iterationTimer :> prevTickMark;
                     nextTickMark = prevTickMark +tickDifference;
                     if (nextTickMark < prevTickMark) {timerRolloverFlag = 1;}//Set time metrics to equivelents

                 }
                 break;
             case fromButtons :> input://Upon receiving input from buttons
                 if (input == 14)//If its button 1
                 {

                     printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );

                     LedOutput = JointLedGreen;
                     transmitLED(LedOutput, c_IO);
                     transmitToWorkers((unsigned char)1, workerChannels);//Inform workers we are loading
                     roundsProcessed = 0;
                     livingCells = distributeInput(c_IO, workerChannels);//distribute input to workers
                     processingOngoing = 1;
                     printf("Image loaded\n");
                     LedOutput = 0;
                     transmitLED(LedOutput, c_IO);

                     roundMark = iterationFrequency;//Reset metrics
                     seconds = 0;
                     minutes = 0;
                     iterationTimer :> prevTickMark;
                     nextTickMark = prevTickMark + ticksPerSecond;
                     tickDifference = 0;
                     if (nextTickMark < prevTickMark) {timerRolloverFlag = 1;}

                 }
                 else//If it is button 2
                 {
                     if (!processingOngoing){break;}//If we have nothing to output ignore it.
                     iterationTimer :> tickInput;
                     if (timerRolloverFlag)//Store times to reset timer metrics once we finish
                     {
                         tickDifference = nextTickMark + (tickInput - prevTickMark);
                     }
                     else
                     {
                         tickDifference = nextTickMark - tickInput;
                     }
                     LedOutput = JointLedBlue;
                     printf("outputting data procedure\n");
                     transmitLED(LedOutput, c_IO);
                     outputData(c_IO, workerChannels);//Output Data to file.
                     LedOutput = 0;
                     transmitLED(LedOutput, c_IO);
                     printf("data output \n");

                     iterationTimer :> prevTickMark;
                     nextTickMark = prevTickMark + tickDifference;
                     if (nextTickMark < prevTickMark) {timerRolloverFlag = 1;}//reset timer metrics
                 }
                 break;
             case ((processingOngoing && running)) => workerChannels [0] [0] :> input:

                     if (roundsProcessed == roundMark)//If round frequency is hit, inform user of metrics.
                     {
                         iterationTimer :> tickInput;

                         roundMark += iterationFrequency;
                         printf("Total execution time for %d iterations: %d:%d.%-9d \n",roundsProcessed, minutes, seconds, nextTickMark - tickInput);

                     }

                     roundsProcessed++;
                     if (greenLedOn)//Flash Led
                     {
                         LedOutput = StandaloneLedGreen;
                         greenLedOn = 0;
                     }
                     else
                     {
                         LedOutput = 0;
                         greenLedOn = 1;
                     }

                     iterateGame(workerChannels);//Iterate Game
                     transmitLED(LedOutput, c_IO);
                     break;
             case (processingOngoing && running) =>  iterationTimer when timerafter(nextTickMark) :> tickInput://Handle timer to produce time metrics
                     if (timerRolloverFlag && (tickInput<prevTickMark)) {timerRolloverFlag = 0;}
                     else
                     {
                         seconds++;
                         if (seconds == 60) {minutes ++; seconds = 0;}
                         prevTickMark = nextTickMark;
                         nextTickMark += ticksPerSecond;
                         if (nextTickMark < prevTickMark) {timerRolloverFlag = 1;}
                     }
                     break;
        }
    }
}



/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrates concurrent system and starts up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
int main(void) {

    i2c_master_if i2c[1];

    chan c_IO, c_control, c_button;
    chan workerChannels [workersWidth] [workersHeight];
    chan verticalChannels [workersWidth] [workersHeight];
    chan horizontalChannels [workersWidth] [workersHeight];

    par {
        on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
        on tile[0]: orientation(i2c[0],c_control);        //client thread reading orientation data
        on tile[0]: IOControl(c_IO);      //thread to handle IO
        on tile[1]: distributor(c_IO, c_control, c_button, workerChannels);//thread to coordinate work on image
        on tile[0]: buttonListener(buttons, c_button);

        par (int i = 0; i<workersWidth; i++)
        {
            par (int j = 0; j<workersHeight; j++)
                                                                                                                        {
                on tile[i]:  worker(workerChannels[i] [j],
                        verticalChannels[i] [j],
                        verticalChannels[i] [(j + 1) % workersHeight],
                        horizontalChannels[i] [j],
                        horizontalChannels[(i + 1) % workersWidth] [j],
                        (i + j) % 2);
                                                                                                                        }
        }

    }

    return 0;
}
