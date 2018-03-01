//////////USER SETTINGS//////////////////////
#define  IMHT 64//Height of image in bits, Max of 1712. Number of bytes must be divisible by workersHeight
#define  IMWD 64 //Width of image in bits, Max of 1712. Number of bytes must be divisible by workersWidth
#define workersHeight 4//Size of Y axis in workerGrid. Must be 2 or more
#define weight 7 //Determines odds of a bit being on during random generation if image not found. Prob(on) = .weight
#define seed 1234567 //Seed used for random generation.
#define fnamein "test64.pgm"//put your input image path here
#define fnameout "testout.pgm" //put your output image path here
#define iterationFrequency 100 //Determines how number of completed iterations between program updating you on its status.
////////SYSTEM SETTINGS//////////////////////
#define bitWidthPerWorker IMWD/workersWidth
#define bitHeightPerWorker IMHT/workersHeight
#define byteWidthPerWorker bitWidthPerWorker/8 //Width of image each worker is responsible for in bytes
#define bufferLength byteWidthPerWorker + 4
#define lifeGrid unsigned char grid [(byteWidthPerWorker)+2] [bitHeightPerWorker + 2]
#define ticksPerSecond 100000000
#define workersWidth 2//Size of X axis in workerGrid. Must be 2 for output code
#define FXOS8700EQ_I2C_ADDR 0x1E  //register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

#define StandaloneLedGreen  1
#define JointLedBlue  2
#define JointLedGreen  4
#define JointLedRed 8


