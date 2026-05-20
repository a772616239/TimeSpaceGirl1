import openpyxl

wb = openpyxl.load_workbook('/Users/wangxufeng/Documents/TimeSpaceGirl1/data_execl/base_data/HeroRankupGroup.xlsx', data_only=True)
sheet = wb.active

headers = []
for cell in sheet[1]:
    headers.append(cell.value)
print("Headers row 1:", headers)

headers2 = []
for cell in sheet[2]:
    headers2.append(cell.value)
print("Headers row 2:", headers2)

headers3 = []
for cell in sheet[3]:
    headers3.append(cell.value)
print("Headers row 3:", headers3)

