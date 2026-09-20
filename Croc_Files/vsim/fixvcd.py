#!/usr/bin/env python3
import sys

# Usage
# ./fixvcd.py croc.vcd croc_fixed.vcd


if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} <in.vcd> <out.vcd>")
    sys.exit(1)

infile, outfile = sys.argv[1], sys.argv[2]
offset = None

with open(infile, 'rb') as fin, open(outfile, 'wb') as fout:
    for raw in fin:
        # If it’s a timestamp line, e.g. b"#12345\n"
        if raw.startswith(b'#'):
            # strip the leading '#' and whitespace, parse as int
            try:
                t = int(raw[1:].strip())
            except ValueError:
                # not a pure timestamp, just pass it through
                fout.write(raw)
                continue
            if offset is None:
                offset = t
                new_t = 0
            else:
                new_t = t - offset
            # write back as ASCII
            fout.write(f"#{new_t}\n".encode('ascii'))
        else:
            # non-# lines are dumped verbatim
            fout.write(raw)

print(f"Rebased VCD: subtracted offset {offset}, output in {outfile}")