import math

angles_deg = [
    0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 195, 210, 225, 240, 255, 270, 285, 300, 315, 330, 345,
    1, 89, 91, 179, 181, 269, 271, 359
]

def to_hex32(val):
    return f"0x{val & 0xFFFFFFFF:08X}"

print("static const cordic_test_vector_t test_vectors[] = {")
for ang in angles_deg:
    angle_fixed = int(round((ang / 360.0) * 102944))
    sin_val = int(round(math.sin(math.radians(ang)) * 32767))
    cos_val = int(round(math.cos(math.radians(ang)) * 32767))
    
    expected_packed = ((sin_val & 0xFFFF) << 16) | (cos_val & 0xFFFF)
    
    print(f"    {{\"\", {to_hex32(angle_fixed)}, {to_hex32(expected_packed)}}}, // {ang} deg")
print("};")
