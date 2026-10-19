from PIL import Image, ImageDraw

a = Image.open("_output/badun_fix/before.png").convert("RGB")
b = Image.open("_output/badun_fix/after.png").convert("RGB")
W, H = a.size
box = (int(W * 0.18), 0, int(W * 0.72), H)
a2, b2 = a.crop(box), b.crop(box)
sc = 1.55
a2 = a2.resize((int(a2.width * sc), int(a2.height * sc)), Image.LANCZOS)
b2 = b2.resize((int(b2.width * sc), int(b2.height * sc)), Image.LANCZOS)
w, h = a2.size
pad, lab = 12, 30
sheet = Image.new("RGB", (2 * w + 3 * pad, h + 2 * pad + lab), (28, 28, 32))
dr = ImageDraw.Draw(sheet)
dr.text((pad + 2, 9), "BEFORE: no texture, hard edges", fill=(255, 150, 150))
dr.text((2 * pad + w + 2, 9), "AFTER: cn2-tex_glow_020 soft falloff", fill=(150, 255, 180))
sheet.paste(a2, (pad, pad + lab))
sheet.paste(b2, (2 * pad + w, pad + lab))
out = "_output/badun_effect_fix_zoom.png"
sheet.save(out)
print(out, sheet.size)
