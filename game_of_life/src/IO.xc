#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <stdlib.h>
#include "pgmIO.h"
#include "i2c.h"
#include "definitions.xc"

on tile[0] : in port buttons = XS1_PORT_4E; //port to access xCore-200 buttons
on tile[0] : out port leds = XS1_PORT_4F;   //port to access xCore-200 LEDs


on tile[0] : port p_scl = XS1_PORT_1E;         //interface ports to orientation
on tile[0] : port p_sda = XS1_PORT_1F;



// Read Image from PGM file from path infname[] to channel c_out. Displays % completion to user.
// If Image not found, randomly generates one according to user settings
void DataInStream(char infname[], chanend c_out)
{
    int res;
    char line[ IMWD ];

    //Open PGM file
    printf( "Writing grid from %s...\n", infname);
    res = _openinpgm( infname, IMWD, IMHT );
    if( res ) {//Failed to find file, randomly generate
        srand(seed);
        int randomNum;
        int limit = RAND_MAX/10;
        int WeightOn = weight * limit;
        printf( "DataInStream: Error openening %s\nPopulating grid with random cells instead of density = %d0%%\n", infname,weight );
        for (int y = 0; y < IMHT; y++)
        {
            for (int x = 0; x < IMHT; x++)
            {
                randomNum = rand();
                if ((randomNum < WeightOn))//
                {
                    c_out <: (unsigned char) 255;
                }
                else
                {
                    c_out <: (unsigned char) 0;
                }
            }
        }
    }
    else//Read file line by lines
    {
        int seperation = (IMHT/10)+1;
        int nextIndex = seperation;
        int percentIndex = 0;//Read image line-by-line and send byte by byte to channel c_out
        for( int y = 0; y < IMHT; y++ ) {
            _readinline( line, IMWD );
            if ((y == nextIndex)&&(percentIndex!=10))//Displays aproximation of percentage completion to user.
            {
                percentIndex++;

                nextIndex += seperation;
                printf("Reading %d0%% complete.\n",percentIndex);
            }
            for( int x = 0; x < IMWD; x++ ) {
                c_out <: line[ x ];
            }
        }
    }

    //Close PGM image file
    _closeinpgm();

}



// Write pixel stream from channel c_in to PGM image file
//  Displays percentage completion to user
void DataOutStream(char outfname[], chanend c_in)
{
    int res;
    char line[ IMWD ];

    //Open PGM file
    printf( "Writing grid to file...\n" );
    res = _openoutpgm( outfname, IMWD, IMHT );
    if( res ) {
        printf( "DataOutStream: Error opening %s\n.", outfname );
    }
    else
    {
        int seperation = IMHT/10;
        int nextIndex = seperation;
        int percentIndex = 0;
        //Compile each line of the image and write the image line-by-line
        for( int y = 0; y < IMHT; y++ ) {
            if ((y == nextIndex) && (percentIndex !=10))//Displays aproximation of percentage completion to user.
            {
                percentIndex++;
                nextIndex += seperation;
                printf("Writing %d0%% complete.\n",percentIndex);
            }
            for( int x = 0; x < IMWD; x++ ) {
                c_in :> line[ x ];
            }
            _writeoutline( line, IMWD );
        }

        //Close the PGM image
        _closeoutpgm();
        printf( "File loaded.\n" );
    }
}


//Displays an LED pattern from distributor to User
//1st bit...separate green LED
//2nd bit...blue LED
//3rd bit...green LED
//4th bit...red LED
void displayLED(chanend distributor)
{
    //receive new pattern from visualiser
    int pattern = 0;
    distributor :> pattern;
    if(pattern < 16){leds <: pattern;}//if pattern is within limits, pass to LED's
}

//Acts as DataInStream, DataOutStream, or displayLED, based on input from toDist
//Contains while(1) loop.
void IOControl(chanend toDist)
{
    unsigned char input = 0;
    while(1)
    {
        toDist :> input;
        switch (input)
        {
            case 0:
                DataInStream(fnamein, toDist);
                break;
            case 1:
                DataOutStream(fnameout,toDist);
                break;
            case 2:
                displayLED(toDist);
                break;
        }
    }
}

//Listens for button presses and notifies the chanend provided
//Contains while(1) loop
void buttonListener(in port b, chanend toDist)
{
    int r;
    while (1) {
        b when pinseq(15)  :> r;
        // check that no button is pressed
        b when pinsneq(15) :> r;    // check if some buttons are pressed
        if ((r==13) || (r==14))     // if either button is pressed sw1 == 14
        {
            toDist <: (char) r;             // send button pattern to userAnt
        }
    }
}


//Initialise and  read orientation, notifies chanend whenever tilt crosses certain threshold
//Contains while (1) loop
void orientation( client interface i2c_master_if i2c, chanend toDist)
{

    i2c_regop_res_t result;
    char status_data = 0;
    int tilted = 0;

    // Configure FXOS8700EQ
    result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
    if (result != I2C_REGOP_SUCCESS) {
        printf("I2C write reg failed\n");
    }

    // Enable FXOS8700EQ
    result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
    if (result != I2C_REGOP_SUCCESS) {
        printf("I2C write reg failed\n");
    }

    //Probe the orientation x-axis forever
    while (1) {

        //check until new orientation data is available
        do {
            status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
        } while (!status_data & 0x08);

        //get new x-axis tilt value
        int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

        //send signal to distributor after first tilt
        if (!tilted) {
            if (x>30) {
                tilted = 1 - tilted;
                toDist <: (char)1;
            }
        }
        else
        {
            if (x<10)
            {
                tilted = 1 - tilted;
                toDist <: (char)1;
            }
        }
    }
}

