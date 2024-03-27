from subprocess import call
import re, sys, os, platform
from optparse import OptionParser
import tempfile
from shutil import copyfile

from intelhex import IntelHex, bin2hex, hex2bin
from io import StringIO, BytesIO

SCHOOL_ID = "B1TSC"

#val = bytes(0xCA,0xFE)

START_OF_PROGMEM = [0xCAFECAFE, 0xCAFECAFE, 0xAAAAAAAA, 0xAAAAAAAA, 0xAAAAAAAA, 0xAAAAAAAA, 0xAAAAAAAA]
HUB_ID = "B1THu"

BUILD_FOLDER_PATH = "./build/bbc-microbit-classic-gcc/source/microbit-samples.hex"

package_directory = os.path.dirname(os.path.abspath(__file__))

parser = OptionParser()

#command line options
parser.add_option("", "--school-id",
                  action="store",
                  type="string",
                  dest="school_id",
                  default="",
                  help="The new school id to splice into the hub hex file")

parser.add_option("", "--PIChex",
                  action="store",
                  type="string",
                  dest="pic_hex",
                  default="",
                  help="the Intel hex file for the PIC (e.g. MPLAB X output)")

parser.add_option("", "--microbithex",
                  action="store",
                  type="string",
                  dest="microbit_hex",
                  default="microbit-samples.hex",
                  help="the Intel hex file for the microbit")

parser.add_option("", "--hub-id",
                  action="store",
                  type="string",
                  dest="hub_id",
                  default="",
                  help="The new hub id to splice into the hub hex file")

parser.add_option("", "--output-file",
                  action="store",
                  type="string",
                  dest="output_file_path",
                  default="./hub-final.hex",
                  help="Output file path")

parser.add_option("-c", "",
                  action="store_true",
                  dest="clean",
                  default=False,
                  help="Copy the latest hex file, and replace hub-not-combined.hex")

(options, args) = parser.parse_args()

"""
    Injects the given ids into a hex file and outputs it as a file (if given a path).
    @param new_school_id the new school id to replace in the hub hex file
    @param new_hub_id the new hub id to replace in the hub hex file
    @param output_file_path the output path (defaults to ./hub-final.hex), if not specified, the file will be returned
    @param clean defaults to False, if set to True, the latest hub-not-combined hex will be pulled from the build dir.
"""


# open has intelhex file? using ihex lib?

# array[0:]

# with open("filename", "r") as f:
#     lines = f.readlines()

#     for l in lines:
#         decode hex



#ih.dump()
def fileSource(name, isWindows=False):
    if isWindows==True:
        return open(name, "w+b" )
    else:
        return tempfile.NamedTemporaryFile(delete="False")


def inject_ids(pic_hex, microbit_hex, output_file_path="", clean=False):

    data = bytes()

    for val in START_OF_PROGMEM:

        data += val.to_bytes(4,'little')

    REGEX_STR = data

#     if len(new_school_id) != len(SCHOOL_ID):
#         print("New school id length (%d) must match the old (%d)" % (len(new_school_id), len(SCHOOL_ID)))
#         return -1

#     if len(new_hub_id) != len(HUB_ID):
#         print("New hub id length (%d) must match the old (%d)" % (len(new_hub_id), len(HUB_ID)))
#         return -1

    print(pic_hex)
    print(microbit_hex)

    
    if clean:
        print("Removing old hub file.")
        os.remove(package_directory + "/hexes/hub-not-combined.hex")

    # if not os.path.isfile(package_directory + "/hexes/hub-not-combined.hex"):
    #     try:
    #         print("Copying latest hub file from: %s" % BUILD_FOLDER_PATH)
    #         copyfile(BUILD_FOLDER_PATH, package_directory + "/hexes/hub-not-combined.hex")
    #     except Exception as e:
    #         print("hub-combined-hex not available")
    
    #work around for Windows error on temporary file usage
    osFlag = platform.system()=="Windows"

    with fileSource("hub_not_combined_modified.hex",osFlag) as hub_not_combined_modified_hex_file, \
            fileSource("hub_not_combined_modified.bin",osFlag) as hub_not_combined_modified_bin_file: #, \
                #tempfile.NamedTemporaryFile(osFlag) as temp_out_file:

        # first convert the uncombined hex file into bin
        # hex_as_bin = hex2bin(package_directory + "/hexes/hub-not-combined.hex", hub_not_combined_modified_bin_file.name)
        hex_as_bin = hex2bin(options.microbit_hex, hub_not_combined_modified_bin_file.name)

#         # replace the old ids with the new.
#         print("Replacing ids.")
        bin_data = hub_not_combined_modified_bin_file.readlines()
        hub_not_combined_modified_bin_file.seek(0)

#         school_id_changed = False
#         hub_id_changed = False
        ih=IntelHex()
        ih.loadhex(pic_hex)
        print("segments",ih.segments())
        segs=ih.segments()

        # for h in range(0,len(segs)):
        #     print("segment",h)
        #     for i in range(segs[h][0],segs[h][1]):
        #         print(hex(ih[i]))

        
        regexed_match = None
        output_lines = []

        for l in bin_data:
            location = re.search(REGEX_STR,l)
            if location:
                lnew = bytearray(l)
                #print(lnew)
                n=location.start()
                print(location)
                #print(n)
                #print(hex(lnew[location.start()]))
                #print(hex(lnew[location.start()+1]))
                for h in range(0,len(segs)):
                    print("segment",h)
                    val=segs[h][0]
                    
                    lnew[n:n+4]=val.to_bytes(4,'little')
                    print("start addr",hex(val))
                    n+=4
                    val=segs[h][1]-segs[h][0]
                    lnew[n:n+4]=val.to_bytes(4,'little')
                    print("length",hex(val))
                    n+=4
                    for i in range(segs[h][0],segs[h][1]):
                        #print(hex(ih[i]))
                        lnew[n]=ih[i]
                        #print(hex(lnew[n]))
                        n+=1
                magic=START_OF_PROGMEM[0];
                lnew[n:n+4]=magic.to_bytes(4,'little')
                lnew[n+4:n+8]=magic.to_bytes(4,'little')
                #print(lnew)
                output_lines+=[lnew]
            else:
            #    print("weeeee")
                output_lines += [l]


        #if not regexed_match:
        #    Explode, throw exception...

        #write output hex file using output_lines
        hub_not_combined_modified_bin_file.writelines(output_lines)
        hub_not_combined_modified_bin_file.flush()
        print(hub_not_combined_modified_bin_file.name)
        print(hub_not_combined_modified_hex_file.name)
        print(package_directory)
      
        # then to hex
        bin2hex(hub_not_combined_modified_bin_file.name, hub_not_combined_modified_hex_file.name, 0x18000)     
        bootloader_hex = IntelHex(package_directory + "/BOOTLOADER.hex")
        softdevice_hex = IntelHex(package_directory + "/SOFTDEVICE.hex")
        replaced_hex = IntelHex(hub_not_combined_modified_hex_file.name)

        replaced_hex.merge(bootloader_hex)
        replaced_hex.merge(softdevice_hex)
        
        #work around for Windows error on temporary file usage
        #SO :facepalm https://stackoverflow.com/questions/23212435/permission-denied-to-write-to-my-temporary-file    
        print("Flag",osFlag);
        if osFlag==True:
            print("Deleting temporary files, since they don't auto-delete")
            hub_not_combined_modified_bin_file.close()
            os.unlink(hub_not_combined_modified_bin_file.name)
            hub_not_combined_modified_hex_file.close()
            os.unlink(hub_not_combined_modified_hex_file.name)
            print("Done deleting...")
            

        print(output_file_path)
#         # finally creating the final binary.
        if len(output_file_path):
            print ("Creating final file: %s" % (output_file_path))
            with open(output_file_path, 'w') as f:
                replaced_hex.write_hex_file(f.name)
                f.close()
                return 0
        else:
            sio = StringIO()
            bio = BytesIO()
            try:
                #python 3
                replaced_hex.write_hex_file(sio)
                return sio.getvalue()
            except:
                #python 2
                replaced_hex.write_hex_file(bio)
                return bio.getvalue()


         # for l in bin_data:
         #     try:
         #         new_l = re.sub(bytes(SCHOOL_ID, 'utf-8'), bytes(new_school_id, 'utf-8'), l)
         #     except:
         #         new_l = re.sub(SCHOOL_ID, new_school_id, l)

#             if new_l != l:
#                 school_id_changed = True

#             try:
#                 final_l = re.sub(bytes(HUB_ID, 'utf-8'), bytes(new_hub_id,'utf-8'), new_l)
#             except:
#                 final_l = re.sub(HUB_ID, new_hub_id, new_l)

#             if final_l != new_l:
#                 hub_id_changed = True

#             hub_not_combined_modified_bin_file.write(final_l)

#         hub_not_combined_modified_bin_file.flush()

#         if not school_id_changed:
#             print("School id not found in bin!")
#             exit(1)

#         if not hub_id_changed:
#             print("Hub id not found in bin!")
#             exit(1)

#         # then to hex
#         bin2hex(hub_not_combined_modified_bin_file.name, hub_not_combined_modified_hex_file.name, 0x18000)
#         replaced_hex = IntelHex(hub_not_combined_modified_hex_file.name)
#         bootloader_hex = IntelHex(package_directory + "/hexes/BOOTLOADER.hex")
#         softdevice_hex = IntelHex(package_directory + "/hexes/SOFTDEVICE.hex")

#         replaced_hex.merge(bootloader_hex)
#         replaced_hex.merge(softdevice_hex)

#         # finally creating the final binary.
#         if len(output_file_path):
#             print ("Creating final file: %s" % (output_file_path))
#             with open(output_file_path, 'w') as f:
#                 replaced_hex.write_hex_file(f.name)
#                 f.close()
#                 return 0
#         else:
#             sio = StringIO()
#             bio = BytesIO()
#             try:
#                 #python 3
#                 replaced_hex.write_hex_file(sio)
#                 return sio.getvalue()
#             except:
#                 #python 2
#                 replaced_hex.write_hex_file(bio)
#                 return bio.getvalue()

if __name__ == '__main__':
    sys.exit(inject_ids(options.pic_hex, options.microbit_hex, options.output_file_path, options.clean))
