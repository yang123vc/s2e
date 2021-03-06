#!/bin/sh
# Copyright (C) 2017, Cyberhaven
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This script automatically extracts kernels from Windows ISO images
# and generates the winmonitor_gen.c file that is used by the S2E kernel
# driver in order to parse internal Windows data structures.
#
# Run this script if you want to add support for a new Windows version.
# After the script is done, rebuild the driver.

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 /path/to/windows/iso/folder"
    exit 1
fi

ISO_DIR="$1"
CUR_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname $0)" && pwd)"
BASE_DIR="$SCRIPT_DIR/../"
OUTPUT_DIR="$BASE_DIR/kernels"
KB_DIR="$BASE_DIR/kb"

WGET="wget --no-use-server-timestamps -O"
DRIVER_OUTPUT="$BASE_DIR/driver/src/winmonitor_gen.c"
PDBPARSER="$CUR_DIR/x64/Release/pdbparser.exe"

if [ ! -f "$PDBPARSER" ]; then
    echo "$PDBPARSER does not exist."
    echo "Please build the s2e.sln solution with Visual Studio in release mode."
    exit 1
fi

if [ ! -d $ISO_DIR ]; then
    echo "$ISO_DIR does not exist"
    exit 1
fi

mkdir -p "$OUTPUT_DIR" "$KB_DIR"

download_patch()
{
    local URL="$1"
    local FILE="$(basename $URL)"
    local DEST_FILE="$KB_DIR/$FILE"
    if [ -f "$DEST_FILE" ]; then
        echo "$DEST_FILE already exists, skipping."
    else
        $WGET "$DEST_FILE" "$URL"
    fi
}

# Download patches for driver signature checks
download_patches()
{
    download_patch https://download.microsoft.com/download/C/8/7/C87AE67E-A228-48FB-8F02-B2A9A1238099/Windows6.1-KB3033929-x64.msu
    download_patch https://download.microsoft.com/download/3/7/4/37473F39-5728-4153-9A25-64C09DE9ED52/Windows6.1-KB3033929-x86.msu

    download_patch http://download.windowsupdate.com/msdownload/update/software/secu/2012/04/windows6.1-kb2676562-x64_446b9165a9a52540896cefb69f6de1d193416056.msu
    download_patch http://download.microsoft.com/download/F/4/B/F4BE818D-22B9-4EF5-8E20-B9C4A605E61E/Windows6.1-KB3004375-v3-x64.msu
    download_patch http://download.windowsupdate.com/d/msdownload/update/software/updt/2016/05/windows6.1-kb3125574-v4-x64_2dafb1d203c8964239af3048b5dd4b1264cd93b9.msu
    download_patch http://download.windowsupdate.com/d/msdownload/update/software/updt/2016/09/windows6.1-kb3172605-x64_2bb9bc55f347eee34b1454b50c436eb6fd9301fc.msu
    download_patch http://download.windowsupdate.com/c/msdownload/update/software/secu/2019/09/windows6.1-kb4474419-v3-x64_b5614c6cea5cb4e198717789633dca16308ef79c.msu
    download_patch http://download.windowsupdate.com/c/msdownload/update/software/secu/2020/01/windows6.1-kb4534310-x64_4dc78a6eeb14e2eac1ede7381f4a93658c8e2cdc.msu

    download_patch http://download.windowsupdate.com/msdownload/update/software/secu/2012/04/windows6.1-kb2676562-x86_16ce9be3400bc75c415b1a90518c150d1927b8df.msu
    download_patch http://download.microsoft.com/download/0/E/3/0E32F39B-1D5E-4B0E-804C-F736DAADDD93/Windows6.1-KB3004375-v3-x86.msu
    download_patch http://download.windowsupdate.com/d/msdownload/update/software/updt/2016/05/windows6.1-kb3125574-v4-x86_ba1ff5537312561795cc04db0b02fbb0a74b2cbd.msu
    download_patch http://download.windowsupdate.com/d/msdownload/update/software/updt/2016/09/windows6.1-kb3172605-x86_ae03ccbd299e434ea2239f1ad86f164e5f4deeda.msu
    download_patch http://download.windowsupdate.com/c/msdownload/update/software/secu/2019/09/windows6.1-kb4474419-v3-x86_0f687d50402790f340087c576886501b3223bec6.msu
    download_patch http://download.windowsupdate.com/c/msdownload/update/software/secu/2020/01/windows6.1-kb4534310-x86_887a5caab59437e8f23aa5a4608950455bb37537.msu

    download_patch https://github.com/S2E/guest-images/releases/download/v2.0.0/winxp-updates-x86-enu.exe
}

extract_kernels()
{
    # Extract kernels from KBs first
    $SCRIPT_DIR/extract_kernels.py  --iso-dir "$KB_DIR" -o "$OUTPUT_DIR"

    # Extract ISOs
    $SCRIPT_DIR/extract_kernels.py  --iso-dir "$ISO_DIR" -o "$OUTPUT_DIR"
}

get_pdbs()
{
    cd "$OUTPUT_DIR"
    for f in *.exe; do
        PDB_FILE="$(basename "${f%.*}.pdb")"
        if [ ! -f "$PDB_FILE" ]; then
            echo "Getting PDB for $f"
            $SCRIPT_DIR/symchk.py "$f"
        fi
    done
    cd "$CUR_DIR"
}

generate_driver()
{
    $SCRIPT_DIR/gendriver.py -d "$OUTPUT_DIR" -p "$PDBPARSER" -o "$DRIVER_OUTPUT"
    echo "The S2E driver file $DRIVER_OUTPUT has been updated. Please rebuild the solution."
}

download_patches
extract_kernels
get_pdbs
generate_driver
