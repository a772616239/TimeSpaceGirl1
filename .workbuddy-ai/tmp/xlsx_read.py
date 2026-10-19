import sys, zipfile, re
from xml.etree import ElementTree as ET

NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
      'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}


def col_to_idx(ref):
    m = re.match(r'([A-Z]+)', ref)
    s = m.group(1)
    n = 0
    for ch in s:
        n = n * 26 + (ord(ch) - 64)
    return n - 1


def read_sheet(path, sheet_name=None, max_rows=None):
    z = zipfile.ZipFile(path)
    shared = []
    if 'xl/sharedStrings.xml' in z.namelist():
        root = ET.fromstring(z.read('xl/sharedStrings.xml'))
        for si in root.findall('m:si', NS):
            txt = ''.join(t.text or '' for t in si.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t'))
            shared.append(txt)
    wb = ET.fromstring(z.read('xl/workbook.xml'))
    sheets = [(s.get('name'), s.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id'))
              for s in wb.find('m:sheets', NS)]
    rels = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
    relmap = {r.get('Id'): r.get('Target') for r in rels}
    if sheet_name:
        sheets = [s for s in sheets if s[0] == sheet_name]
    out = {}
    for name, rid in sheets:
        target = relmap[rid]
        if not target.startswith('xl/'):
            target = 'xl/' + target.lstrip('/')
        root = ET.fromstring(z.read(target))
        rows = []
        for row in root.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}row'):
            cells = {}
            for c in row.findall('m:c', NS):
                ref = c.get('r')
                t = c.get('t')
                v = c.find('m:v', NS)
                isel = c.find('m:is', NS)
                if t == 's' and v is not None:
                    val = shared[int(v.text)]
                elif t == 'inlineStr' and isel is not None:
                    val = ''.join(x.text or '' for x in isel.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t'))
                elif v is not None:
                    val = v.text
                else:
                    val = ''
                cells[col_to_idx(ref)] = val
            if cells:
                width = max(cells) + 1
                rows.append([cells.get(i, '') for i in range(width)])
            if max_rows and len(rows) >= max_rows:
                break
        out[name] = rows
    return out


if __name__ == '__main__':
    path = sys.argv[1]
    sheet = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != '-' else None
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    data = read_sheet(path, sheet, n or None)
    for name, rows in data.items():
        print('### SHEET', name, len(rows))
        for r in rows:
            print(' | '.join(str(x) for x in r))
