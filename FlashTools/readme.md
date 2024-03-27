## Flashing a program to PIC (step-by-step)

### Install steps
 1. Check for Python and Pip
```shell
python --version
pip --version
```
 2. If either are not available, install them. AppsAnywhere has a default Python setup if you need this on your own computing device.
 3. Check if intelhex is available using pip
```shell
pip freeze
```
 4. If intelhex is unavailable, install it
```shell
pip install --user intelhex
```
 5. The FlashTools folder should be downloaded to an accessible location on your device. Avoid long path names
***Note:*** _Above steps are needed one-time only for each device you will be using. 
For lab machines, Python and intelhex should come pre-installed. Also, use python3 instead of python _

### Flash steps  

 1. Build the project in MPLAB X IDE and note the output location in the Build output dialog.
 2. Copy the .hex file from the build folder to the FlashTools folder OR specify the complete path to the .hex file in the command in step 3.
 3. Create the hub-final.hex file using the following command:
 ```shell
python inject.py --PIChex yourHexFile.hex
 ```
 4. Connect the micro:bit to your computing device
 5. Copy the hub-final.hex file to the micro:bit
 5a. For Windows devices, the micro:bit shows up as a drive, which you can drag and drop the file onto (OR use the copy command from the command prompt)
 5b. For Linux devices, use the copy command
 ```shell
cp hub-final.hex /media/[username]/MICROBIT
 ```
 6. If the command succeeds you should see the micro:bit will blink as the copy process occurs. Once done, your program should start working.