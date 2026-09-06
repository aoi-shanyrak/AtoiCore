import os
import sys


def generate_payload(filename, num_sectors):
    sector_size = 512
    total_bytes = num_sectors * sector_size
    pattern = bytes(range(256)) 
    repeats = total_bytes // 256  
    data = (pattern * repeats)[:total_bytes]

    with open(filename, 'wb') as f:
        f.write(data)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(1)

    filename = sys.argv[1]
    try:
        num_sectors = int(sys.argv[2])
    except ValueError:
        sys.exit(1)

    generate_payload(filename, num_sectors)
    