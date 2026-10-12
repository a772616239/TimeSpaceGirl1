#!/usr/bin/env python3
"""包内 native 库 16KB / NDK 体检（离线解包 AAB，不走 Play API）。

背景（2026-10-12 真机/Play 实测）：
  Play 的 16KB 合规有**两层**：
    ① 硬门槛：每个 64 位 .so 的 PT_LOAD p_align 必须 >= 16384。不满足 => 直接不合规。
    ② 软告警「库是使用旧版 Android NDK 编译的」：Play 会点名部分库。
  实测点名的 `libnative-googlesignin.so` 有两个独有特征（本包内 13 个 .so 中唯一）：
    - `.note.android.ident` = r17（全包唯一 < r19 的）
    - `.comment` 段里混有 `GCC: (GNU) 4.9.x`（全包唯一带 GCC 的）
    - p_align = 0x10000（全包唯一的 64KB 对齐，其余全是 0x4000）
  而 Play **未**点名的 Firebase(r21e) / il2cpp(r23b) / unity(r23b) 都是 0x4000 且无 GCC 段。
  ⇒ 本脚本：
     FAIL 条件 = 任何 64 位 .so 的 LOAD 对齐 < 16384（Play 硬门槛）
     WARN 条件 = 命中「GCC .comment」或「p_align == 0x10000」或「NDK note < r19」（软告警候选）

用法：
    verify_aab_native_16kb.py <aab> [--strict]
      默认：硬门槛不过则 rc=1；软告警只打印。
      --strict：软告警也 rc=1（发版前想彻底清零时用）。
"""
import argparse
import struct
import sys
import zipfile

SIXTY_FOUR = ('arm64-v8a', 'x86_64')


def _parse_elf(d):
    if d[:4] != b'\x7fELF':
        return None
    is64 = d[4] == 2
    endian = '<' if d[5] == 1 else '>'
    if is64:
        e_phoff = struct.unpack_from(endian + 'Q', d, 0x20)[0]
        e_shoff = struct.unpack_from(endian + 'Q', d, 0x28)[0]
        e_phentsize = struct.unpack_from(endian + 'H', d, 0x36)[0]
        e_phnum = struct.unpack_from(endian + 'H', d, 0x38)[0]
        e_shentsize = struct.unpack_from(endian + 'H', d, 0x3a)[0]
        e_shnum = struct.unpack_from(endian + 'H', d, 0x3c)[0]
        e_shstrndx = struct.unpack_from(endian + 'H', d, 0x3e)[0]
    else:
        e_phoff = struct.unpack_from(endian + 'I', d, 0x1c)[0]
        e_shoff = struct.unpack_from(endian + 'I', d, 0x20)[0]
        e_phentsize = struct.unpack_from(endian + 'H', d, 0x2a)[0]
        e_phnum = struct.unpack_from(endian + 'H', d, 0x2c)[0]
        e_shentsize = struct.unpack_from(endian + 'H', d, 0x2e)[0]
        e_shnum = struct.unpack_from(endian + 'H', d, 0x30)[0]
        e_shstrndx = struct.unpack_from(endian + 'H', d, 0x32)[0]

    aligns = []
    for i in range(e_phnum):
        o = e_phoff + i * e_phentsize
        if struct.unpack_from(endian + 'I', d, o)[0] != 1:  # PT_LOAD
            continue
        if is64:
            aligns.append(struct.unpack_from(endian + 'Q', d, o + 0x30)[0])
        else:
            aligns.append(struct.unpack_from(endian + 'I', d, o + 0x1c)[0])

    sh_str_off = struct.unpack_from(
        endian + ('Q' if is64 else 'I'), d,
        e_shoff + e_shstrndx * e_shentsize + (0x18 if is64 else 0x10))[0]

    def nm(off):
        e = d.index(b'\x00', sh_str_off + off)
        return d[sh_str_off + off:e].decode(errors='replace')

    secs = {}
    for i in range(e_shnum):
        o = e_shoff + i * e_shentsize
        name = nm(struct.unpack_from(endian + 'I', d, o)[0])
        if is64:
            secs[name] = (struct.unpack_from(endian + 'Q', d, o + 0x18)[0],
                          struct.unpack_from(endian + 'Q', d, o + 0x20)[0])
        else:
            secs[name] = (struct.unpack_from(endian + 'I', d, o + 0x10)[0],
                          struct.unpack_from(endian + 'I', d, o + 0x14)[0])

    ndk = None
    if '.note.android.ident' in secs:
        off, size = secs['.note.android.ident']
        seg = d[off:off + size]
        ns, ds, _ = struct.unpack_from(endian + 'III', seg, 0)
        doff = 12 + ((ns + 3) // 4) * 4
        desc = seg[doff:doff + ds]
        if len(desc) >= 4:
            vlen = struct.unpack_from(endian + 'I', desc, 0)[0]
            ndk = desc[4:4 + vlen].decode(errors='replace').strip('\x00')

    comment = []
    if '.comment' in secs:
        off, size = secs['.comment']
        comment = [c.decode(errors='replace')
                   for c in d[off:off + size].split(b'\x00') if c]

    return dict(is64=is64, aligns=aligns, ndk=ndk, comment=comment)


def ndk_num(tag):
    """'r28c' / 'r21e' / 'r17' -> 28 / 21 / 17；解析不出返回 None。"""
    if not tag:
        return None
    t = tag.strip().lstrip('rR')
    num = ''
    for ch in t:
        if ch.isdigit():
            num += ch
        else:
            break
    return int(num) if num else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('aab')
    ap.add_argument('--strict', action='store_true',
                    help='软告警也视为失败')
    args = ap.parse_args()

    z = zipfile.ZipFile(args.aab)
    names = sorted(n for n in z.namelist()
                   if n.endswith('.so') and '/lib/' in n)
    if not names:
        print('  ! 包内没有 .so（纯 Java 应用则天然合规）')
        return 0

    hard_bad = []
    soft_bad = []
    print(f"  {'库':52s} {'ABI':12s} {'对齐':>8s} {'NDK':>6s}  备注")
    for n in names:
        parts = n.split('/')
        abi = parts[2] if len(parts) > 3 else '?'
        d = z.read(n)
        r = _parse_elf(d)
        if not r:
            print(f"  {n:52s} {abi:12s} {'-':>8s} {'-':>6s}  非 ELF，跳过")
            continue
        mn = min(r['aligns']) if r['aligns'] else 0
        align_s = hex(mn)
        notes = []
        is64 = abi in SIXTY_FOUR
        if is64 and mn < 16384:
            hard_bad.append((n, align_s))
            notes.append('🔴 对齐 <16KB（Play 硬门槛）')
        has_gcc = any('GCC:' in c for c in r['comment'])
        nn = ndk_num(r['ndk'])
        # 软告警规则：只用实测能**唯一**区分「Play 点名 / 未点名」的两个信号。
        #   - NDK note < r19（本包其余最低为 r21e）
        #   - 64 位库用 64KB 对齐（本包其余全是 0x4000）
        # 单独看 `.comment` 含 GCC 会误伤（libFirebaseCppApp r21e 也带 GCC 却未被点名），
        # 故 GCC 只作为附注，不单独触发。
        soft = False
        if nn is not None and nn < 19:
            soft = True
            notes.append(f'⚠️ NDK note {r["ndk"]} 过旧（< r19）')
        if is64 and mn == 0x10000:
            soft = True
            notes.append('⚠️ 64KB 对齐（非 16KB 工具链默认值）')
        if has_gcc and soft:
            notes.append('附注：.comment 含 GCC')
        if soft:
            soft_bad.append(n)
        print(f"  {n.split('base/lib/')[-1]:52s} {abi:12s} {align_s:>8s} "
              f"{(r['ndk'] or '-'):>6s}  {' / '.join(notes)}")

    print()
    if hard_bad:
        print(f"  ✗ {len(hard_bad)} 个 64 位库未达 16KB 对齐（Play 硬门槛不过）")
        for n, a in hard_bad:
            print(f"      {n}  align={a}")
    else:
        print(f"  ✓ 全部 {len(names)} 个 .so 均满足 64 位 16KB 对齐硬门槛")

    if soft_bad:
        print(f"  ⚠️ {len(soft_bad)} 个库命中「旧工具链」特征（Play 软告警候选）：")
        for n in soft_bad:
            print(f"      {n.split('base/lib/')[-1]}")
        print("     注意：Firebase/il2cpp/unity 等厂商库长期处于此列，Play 并未点名；"
              "点名与否以 Play Console 实际提示为准。")
    else:
        print("  ✓ 无库命中「旧工具链」特征")

    if hard_bad:
        return 1
    if args.strict and soft_bad:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
