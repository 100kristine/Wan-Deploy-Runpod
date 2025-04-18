#!/bin/bash

# Number of bells to ring (default: 1)
BELLS=${1:-1}

# Function to ring the bell
ring_bell() {
    echo -e "\a"  # ASCII bell character
    sleep 0.5     # Wait half a second between rings
}

# Ring the bell the specified number of times
for ((i=1; i<=$BELLS; i++)); do
    ring_bell
done 